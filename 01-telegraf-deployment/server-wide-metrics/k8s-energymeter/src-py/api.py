from collections import namedtuple
from getpass import getpass
import argparse
import configparser
import http.server
import json
import logging
import os
import re
import requests
import sys
import time
import threading


Credentials = namedtuple("Credentials", "username,password")

data_lock = threading.Lock()
energy_data = None


class ConfigFile():
    def __init__(self, credentials_file=None, logger=None):
        self._file_path = credentials_file
        if logger:
            self.logger = logger
        else:
            self.logger = logging.getLogger("ConfigFile")
        if credentials_file:
            try:
                self._config = configparser.ConfigParser()
                self._config.read(self._file_path)
            except Exception as e:
                self.logger.error(str(e))
                raise
        else:
            self._file_path = None
            self._config = {}

    def _get_credential(self, credential):
        if credential in self._config:
            section = self._config[credential]
            if "username" in section and "password" in section:
                return Credentials(section["username"], section["password"])
        self.logger.warning("Credentials for '%s' not found", credential)
        return None

    @property
    def area(self):
        return self._get_credential("area")

    #@property
    #def energyteam(self):
    #    return self._get_credential("energyteam")

    @property
    def http_auth_required(self):
        output = False
        if "application" in self._config:
            app_conf = self._config["application"]
            output = app_conf.get("http_auth_required", False)
        return output

    @property
    def listening_address(self):
        bind_address = ""
        bind_port = 8080
        if "application" in self._config:
            app_conf = self._config["application"]
            bind_address = app_conf.get("bind_address", "")
            if "bind_port" in app_conf:
                bind_port = self._config.getint("application", "bind_port")
                bind_port = bind_port if bind_port > 0 and bind_port < 65536 else 8080
        return (bind_address, bind_port)

    @property
    def polling_interval(self):
        return self._config.getint("application", "polling_interval", fallback=300)


#potenza totale letta da zabbix 2033


    @property
    def channel_range(self):
        output = (1963, 1984)
        if "application" in self._config:
            app_conf = self._config["application"]
            if "channel_range" in app_conf:
                cr_string = app_conf["channel_range"]
                a, _, b = cr_string.partition(",")
                try:
                    a = int(a)
                    b = int(b)
                except ValueError:
                    self.logger.warning("Invalid channel range: '%s'", cr_string)
                    a = 1963
                    b = 1984
                if a <= b:
                    output = (a, b)
                else:
                    output = (b, a)
        return output

    @property
    def url(self):
        if "application" in self._config:
            app_conf = self._config["application"]
            url = app_conf.get("url", None)
            return url
        else:
            return None


class API_request():
    BASE_URL = "http://energyteam.area.trieste.it/"

    def __init__(self, url=None, area_login=None, logger=None):
    #    self.energyteam_login = energyteam_login
        self.base_url = url if url else self.BASE_URL
        self.http_auth = None
        if isinstance(area_login, Credentials):
            self.http_auth = (area_login.username,
                              area_login.password)
        if logger:
            self.logger = logger
        else:
            self.logger = logging.getLogger("API_request")

    def start_session(self):
        self.session = requests.Session()

    @staticmethod
    def check_status(result):
        if result["status"] != 1:
            raise Exception(f"Error {result}")

 #   def _a_login(self):
 #       try:
 #           r = self.session.get(self.base_url, auth=self.http_auth)
 #           r.raise_for_status()
 #       except Exception as e:
 #           self.logger.error("Area login error: %s", e)
 #          raise e

    def _a_login(self):
        try:
            url = self.base_url.rstrip("/") + "/api/login.do"
            r = self.session.get(
                url,
                params={
                "method": "login",
                "userName": self.http_auth[0],
                "password": self.http_auth[1],
                },
                timeout=20
            )
            r.raise_for_status()

            j = r.json()
            if j.get("status") != 1:
                raise Exception(f"Login API failed: {j}")

        except Exception as e:
            self.logger.error("API login error: %s", e)
            raise



    def login(self):
        self.logger.debug("Logging in '%s'.", self.base_url)
        self.start_session()
        self._a_login()
        #self._e_login()
        self.logger.debug("Login completed.")


    def logout(self):
        url = self.base_url + "api/login.do"
        r = self.session.get(url,
                             auth=self.http_auth,
                             params={"method": "logout"})


    def request_range(self, startID, endID=None):
        if endID is None:
            endID = startID
        s = ",".join(map(str, range(startID, endID+1)))

        url = self.base_url + "api/realTime.do"
        r_params = {"method": "getRealtimeMeasurements", "vcIds": s}
        r = self.session.get(url,
                            # auth=self.http_auth,
                             params=r_params,
                             timeout=20)
        r.raise_for_status()
        return r.json()


class MyRequestHandler(http.server.BaseHTTPRequestHandler):
    logger = logging.getLogger("HTTPRequestHandler")

    @staticmethod
    def _et_datetime_to_iso8601(dt_string):
        dt_re = r'(?P<day>[0-3]\d)(?P<month>[0-1]\d)(?P<year>\d{4})(?P<hours>[0-2][0-9])(?P<minutes>[0-6]\d)(?P<seconds>[0-6]\d)'
        m = re.match(dt_re, dt_string)
        if m:
            return "%s-%s-%sT%s:%s:%s" % (m.group('year'),
                                          m.group('month'),
                                          m.group('day'),
                                          m.group('hours'),
                                          m.group('minutes'),
                                          m.group('seconds'))
        else:
            raise ValueError("Invalid datetime string: %s" % dt_string)

    def _get_data(self):
        global data_lock
        global energy_data
        output = []
        with data_lock:
            if isinstance(energy_data, dict) and "vcIds" in energy_data:
                for vc_id in energy_data["vcIds"]:
                    key = None
                    try:
                        key = "v%d" % int(vc_id)
                    except ValueError:
                        continue
                    if key in energy_data:
                        tmp_d = {"vcid": vc_id}
                        tmp_d["name"] = energy_data[key].get("name", None)
                        tmp_d["data"] = energy_data[key].get("data", None)
                        tmp_d["unit"] = energy_data[key].get("unit", {}).get("unit", None)
                        ts = ""
                        try:
                            dt_string = energy_data[key].get("lastUpdate", None)
                            ts = self._et_datetime_to_iso8601(dt_string)
                        except ValueError as e:
                            self.log_error("%s", e)
                        tmp_d["timestamp"] = ts
                        output.append(tmp_d)
        return output

    def log_error(self, format_string, *args):
        self.logger.error(format_string, *args)

    def log_message(self, format_string, *args):
        self.logger.info(format_string, *args)

    def do_GET(self):
        if self.path == "/":
            self.send_response(301, "Moved Permanently")
            rdr_loc = "http://%s:%s/api" % self.server.server_address
            self.send_header("Location", rdr_loc)
            self.end_headers()
        elif self.path == "/api":
            self._api_GET()
        elif self.path == "/csv":
            self._csv_GET()
        elif self.path == "/json":
            self._json_GET()
        elif self.path == "/metrics":
            self._prometheus_GET()
        else:
            self.send_error(404)
            self.end_headers()

    def _api_GET(self):
        self.send_response(200, "OK")
        self.send_header("Content-Type", "text/html; Charset=UTF-8")
        self.end_headers()
        outstr = """<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="" xml:lang="">
  <head>
    <meta charset="utf-8" />
    <title>API help</title>
  </head>
  <body>
    <h1>API help</h1>
    <ul>
      <li>GET /api : this page</li>
      <li>GET /csv : return data in comma separated values (CSV) format</li>
      <li>GET /json : return data in JSON format</li>
      <li>GET /metrics : return data in prometheus format</li>
    </ul>
  </body>
</html>
"""
        self.wfile.write(outstr.encode("utf-8"))

    def _csv_GET(self):
        self.send_response(200, "OK")
        self.send_header("Content-Type", "text/csv; Charset=UTF-8")
        self.end_headers()
        data = self._get_data()
        self.wfile.write('"timestamp","vcId","name","data","unit"\r\n'.encode("utf-8"))
        for datapoint in data:
            outstr = '"%s",%d,"%s",%s,"%s"\r\n' % (datapoint["timestamp"],
                                                   datapoint["vcid"],
                                                   datapoint["name"],
                                                   datapoint["data"],
                                                   datapoint["unit"])
            self.wfile.write(outstr.encode("utf-8"))
        self.wfile.flush()

    def _prometheus_GET(self):
        self.send_response(200, "OK")
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        data = self._get_data()
        for datapoint in data:
            outstr = "# " + datapoint["name"] + "\n"
            outstr += "vcId_"
            outstr += str(datapoint["vcid"])
            outstr += "{unit=\"%s\"} %s\n" % (datapoint["unit"], datapoint["data"])
            self.wfile.write(outstr.encode("utf-8"))
        self.wfile.flush()

    def _json_GET(self):
        self.send_response(200, "OK")
        self.send_header("Content-Type", "application/json; Charset=UTF-8")
        self.end_headers()
        data = self._get_data()
        self.wfile.write(json.dumps(data).encode("utf-8"))
        self.wfile.flush()


def do_request(req, cr_range, polling_interval):
    global data_lock
    global energy_data

    logger = getattr(req, "logger", logging.getLogger("do_request"))
    cr_start, cr_stop = cr_range
    while True:
        mydata = None
        try:
            req.login()
            mydata = req.request_range(cr_start, cr_stop)

            if isinstance(mydata, dict) and mydata.get("status", 0) != 1:
                logger.error("Error returned eror: %s", mydata)
                mydata = None
        except Exception as e:
            logger.error("Polling error: %s", e)
        finally:
            try:
                req.logout()
            except Exception as e: 
                logger.debug("Logout failed (ignored): %s", e)
        
        
        if mydata is not None:
            with data_lock:
                energy_data = mydata
        time.sleep(polling_interval)


if __name__ == "__main__":

    verbose_level = logging.WARNING
    parser = argparse.ArgumentParser()
    parser.add_argument('-c',
                        action="store",
                        default="",
                        help="set configuration file path",
                        required=True,
                        dest="configfile")
    parser.add_argument('-v',
                        '--verbose',
                        action="count",
                        default=0,
                        help="increase verbosity",
                        dest="verbose")

    parsed_args = parser.parse_args()

    if parsed_args.verbose == 1:
        verbose_level = logging.INFO
    elif parsed_args.verbose >= 2:
        verbose_level = logging.DEBUG

    app_logger = logging.getLogger("Application")
    app_config = None
    area_login = None
    #energyteam_login = None

    if parsed_args.configfile:
        config_path = os.path.normpath(parsed_args.configfile)
        if not os.path.isfile(config_path):
            app_logger.error("Configuration file '%s' is not a regular file.",
                               config_path)
            sys.exit(99)
        else:
            app_config = ConfigFile(config_path)
            #energyteam_login = app_config.energyteam
            if app_config.http_auth_required:
                _u = os.environ.get("ENERGYMETER_USERNAME", "")
                _p = os.environ.get("ENERGYMETER_PASSWORD", "")
                if _u and _p:
                    area_login = Credentials(_u, _p)
                else:
                    area_login = None
    else:
        app_logger.error("No config file provided.")
        sys.exit(99)

    if app_config.http_auth_required and area_login is None:
        app_logger.error("Missing environment variables ENERGYMETER_USERNAME/ENERGYMETER_PASSWORD.")
        sys.exit(99)

    #if energyteam_login is None:
    #    energyteam_login = Credentials(input("Energyteam username: "),
    #                                   getpass("Energyteam login password:"))

    logging.basicConfig(format="%(asctime)s [%(levelname)s]: %(message)s",
                        level=verbose_level)

    req = API_request(url=app_config.url, area_login=area_login)
    poll_t = threading.Thread(target=do_request,
                              args=(req,
                                    app_config.channel_range,
                                    app_config.polling_interval),
                              daemon=True)
    poll_t.start()
    time.sleep(1)
    addr, port = app_config.listening_address
    if not addr:
        addr = "INADDR_ANY"
    app_logger.info("Listening on %s port %s", addr, port)
    server = http.server.HTTPServer(app_config.listening_address, MyRequestHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        app_logger.warning("Ctrl-C received: exiting...")
        time.sleep(1)
        sys.exit(0)
