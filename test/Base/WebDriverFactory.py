#!/usr/bin/env python2


__author__ = 'jkrzemien@plos.org'

import Config
import json
import os
from datetime import datetime
from time import time
from inspect import getfile
from os.path import abspath, dirname
from os import getenv

from selenium import webdriver
from selenium.webdriver.support.events import EventFiringWebDriver
from selenium.webdriver.firefox.firefox_binary import FirefoxBinary
from browsermobproxy import Server
from appium import webdriver as appiumDriver
from WebDriverListener import WebDriverListener

from Resources import docs


class WebDriverFactory(object):
  server = None
  proxy = None
  driver = None

  def __is_android_device(self, capabilities):
    """
    *Private* method to detect if current browser is an Android based one.

    `capabilities`: Current browser capabilities

    **Returns** `True` if Android, `False` otherwise
    """
    try:
      isAndroid = capabilities['platformName'] is 'Android'
    except KeyError:
      isAndroid = False
    return isAndroid

  def __is_ios_device(self, capabilities):
    """
    *Private* method to detect if current browser is an IOS based one.

    `capabilities`: Current browser capabilities

    **Returns** `True` if IOS, `False` otherwise
    """
    try:
      isIOS = capabilities['platformName'] is 'iOS'
    except KeyError:
      isIOS = False
    return isIOS

  def setup_remote_webdriver(self, capabilities):
    """
    Instantiates a remote web driver

    `capabilities`: *Desired capabilities* for the browser to create

    **Returns** A remote web driver/Appium instance
    """

    is_android = self.__is_android_device(capabilities)
    is_ios = self.__is_ios_device(capabilities)
    is_appium = is_android or is_ios

    # If framework is set to run on **Selenium Grid**
    if Config.run_against_grid == True:
      print '\nRunning on Selenium Grid'
      kwargs = {'desired_capabilities': capabilities}
      kwargs['command_executor'] = Config.selenium_grid_url
      driver = EventFiringWebDriver(webdriver.Remote(**kwargs), WebDriverListener())
    else:
      # If `browser` is an **Appium** device *and* framework is set to run Appium **ONLY**
      if is_appium and Config.run_against_appium == True:
        print '\nRunning on Appium stand-alone mode (not through Selenium Grid)'
        driver = self.__android(capabilities) if is_android else self.__ios(capabilities)

    # Configure default time out (for all cases)
    driver.implicitly_wait(Config.wait_timeout)
    return driver

  def setup_webdriver(self, profile=None, name="statistics"):
    """
    Initializes a simple (local) web driver instance using Firefox browser.
    Accepts a Firefox profile for further customization.

    `profile`: a Firefox profile to include at browser launch

    `name`: a name for the resulting HAR file generated by BrowserMob proxy

    **Returns** a web driver instance of a Firefox browser
    """
    mime_types = 'application/pdf, ' \
                 'application/vnd.openxmlformats-officedocument.wordprocessingml.document, ' \
                 'application/msword, ' \
                 'application/octet-stream, ' \
                 'application/download, ' \
                 'text/plain'
    # Set up a default Firefox profile, if not specified
    if not profile:
      profile = webdriver.FirefoxProfile()
      profile.set_preference('browser.download.dir', '/tmp')
      profile.set_preference('browser.download.folderList', 2)
      profile.set_preference('browser.download.manager.showWhenStarting', False)
      profile.set_preference('plugin.disable_full_page_plugin_for_types', mime_types)
      profile.set_preference('pdfjs.disabled', True)
      profile.set_preference('pdfjs.previousHandler.alwaysAskBeforeHandling', False)
      profile.set_preference('pdfjs.previousHandler.preferredAction', 4)
      profile.set_preference('browser.helperApps.neverAsk.saveToDisk', mime_types)

    # Set up BrowserMob proxy, if enabled
    if Config.browsermob_proxy_enabled:
      self.proxy = self.__setup_browsermob_proxy();
      profile.set.proxy(self.proxy.selenium_proxy())
      self.proxy.new_har(name)

    # Create and return a Web Driver instance
    return self.__get_firefox_webdriver_instance(profile)

  def teardown_webdriver(self):
    """
    Terminates a Web Driver & Proxy instances, if any.
    """

    # Terminate BrowserMob proxy, if present
    if Config.browsermob_proxy_enabled and self.proxy:
      # Retrieve HAR JSON blob from proxy, if any.
      har = self.proxy.har

      # Terminate BrowserMob proxy connections
      self.proxy.close()

      # Save HAR contents to disk
      with open(self.__generate_har_filename(), "w") as harFile:
        json.dump(har, harFile)

      # Terminate BrowserMob proxy server process
      self.__teardown_browsermob_proxy()

    # Terminate Web Driver instance, if any
    if self.driver:
      self.driver.quit()

  def __setup_browsermob_proxy(self):
    """
    Starts BrowserMob proxy server

    **Returns** a Proxy object representing the started proxy server
    """
    self.server = Server(Config.browsermob_proxy_path)
    self.server.start()
    return self.server.create_proxy()

  def __teardown_browsermob_proxy(self):
    """
    Stops the proxy server, if running
    """
    if self.server:
      self.server.stop()

  def __generate_har_filename(self):
    """
    Generates a name for the HAR file to be generated by BrowserMob proxy.
    Format: `/Output/TestRun-YYYY-MM-DD-HHMMSS.har`

    **Returns** a string containing the path to the future HAR file
    """
    ts = time()
    timestamp = datetime.fromtimestamp(ts).strftime('%Y%m%d-%H%M%S')
    path = dirname(abspath(getfile(WebDriverFactory)))
    return '%s/../Output/TestRun-%s.har' % (path, timestamp)

  def __get_firefox_webdriver_instance(self, profile=None):
    """
    Initializes a simple (local) web driver instance using Firefox browser.
    Accepts a Firefox profile for further customization.

    `profile`: a Firefox profile to include at browser launch

    **Returns** a Web Driver instance of a Firefox browser
    """
    ff_path = getenv('ff_path', 'default')
    if ff_path == 'default':
      driver = webdriver.Firefox(firefox_profile=profile)
    else:
      driver = webdriver.Firefox(firefox_profile=profile, firefox_binary=FirefoxBinary(ff_path))

    efDriver = EventFiringWebDriver(driver, WebDriverListener())
    efDriver.implicitly_wait(Config.wait_timeout)
    efDriver.set_page_load_timeout(Config.page_load_timeout)
    efDriver.set_window_size(1280, 1024)
    return efDriver

  # === Appium specific section ===

  def __create_appium_driver(self, url, capabilities):
    """
    Instantiates an Appium RemoteWebDriver.

    `url`: a URL pointing to Appium **server** (not Selenium Grid)

    `capabilities`: Desired capabilities for the Appium device

    **Returns** an Appium RemoteWebDriver instance
    """
    try:
      driver = appiumDriver.Remote(url, capabilities)
    except Exception as e:
      print '\t[WebDriver/Appium error] An error occurred while attempting to contact Appium URL.'
      print '\tURL used: %s' % url
      print '\tCapability used:'
      print '\t%s' % capabilities
      raise e
    return EventFiringWebDriver(driver, WebDriverListener())

  # === Android section ===

  def __android(self, capabilities):
    """

    *Private* method to instantiate a WebDriver connection against *Appium* attached to a real or virtual *Android* device.

    **Requirements**:

    1. **Android SDK** installed, configured and working
    2. **Android VM/hardware device** running/attached to machine

    """
    return self.__create_appium_driver(Config.appium_android_node_url, capabilities)

  # === iOS section ===

  def __ios(self, capabilities):
    """
    *Private* method to instantiate a WebDriver connection against *Appium* attached to a real or virtual *iOS* device.

    **Requirements**:

    1. Macintosh hardware
    2. Mac OS X 10.7 or higher, 10.9.2 recommended
    3. XCode >= 4.6.3, 5.1.1 recommended
    4. Apple Developer Tools (iPhone simulator SDK, command line tools)

    **For Real Mode only:**

    1. An Apple Developer ID and a valid Developer Account with a configured distribution certificate and provisioning profile.
    2. An iPad or iPhone.
    3. A signed .ipa file of your app, or the source code to build one.
    4. Have the [ios-webkit-debug-proxy](https://github.com/google/ios-webkit-debug-proxy) installed, running and listening on port 27753
    5. Turn on web inspector on iOS device (settings > safari > advanced, only for iOS 6.0 and up)
    6. Create a provisioning profile that can be used to deploy the SafariLauncherApp.

    Refer to [Appium documentation](http://appium.io/slate/en/master/?python#mobile-safari-on-a-real-ios-device) for a detailed
    explanation.

    """
    return self.__create_appium_driver(Config.appium_ios_node_url, capabilities)
