#!/usr/bin/env python3
from nerodia.browser import Browser
from selenium.common.exceptions import WebDriverException, UnexpectedAlertPresentException
from psutil import Process
import random
from time import sleep
import sys
import os
import argparse
import atexit

sys.path.append(os.path.join(os.path.dirname(__file__), "lib"))
from urls import urls
import params

argp = argparse.ArgumentParser(description='Drive chromium through the workload set up in the directory')
argp.add_argument("--chrome-binary", action='store', default=None, help="Override path to chrome binary")
argp.add_argument("--chrome-stdout", action='store', default=None, help="Output chrome's stdout/stderr to file")
args = argp.parse_args()


random.seed(params.seed)

def cumsum(lst, cap):
    a = 0
    for x in lst:
        a = a + x
        if a > cap:
            break
        yield a

urls = list(urls)
urls_partitioned = [0]
urls_partitioned.extend(cumsum((2**random.choice(range(7)) for i in iter(int, 1)), len(urls)))
urls_partitioned = [urls[slice(s, e)] for s, e in zip(urls_partitioned, urls_partitioned[1:])]

driver_opts = {'desired_capabilities': {
                    'loggingPrefs': {'browser': 'ALL'},
                },
              }
browser_opts = {'args': ['--single-process',
                         '--browser-startup-dialog',   # browser awaits for SIGUSR1 before launching fully
                         #'--headless',
                        ],
               }
if args.chrome_binary is not None:
    browser_opts['binary'] = args.chrome_binary
if args.chrome_stdout is not None:
    # service_args processing requires patching nerodia.Capabilites._process_arguments()
    driver_opts['service_args'] = ['--verbose', '--log-path={0}'.format(args.chrome_stdout)]
browser = Browser(browser='chrome', options=browser_opts, **driver_opts)

#def at_exit_print_browser_output(browser):
#    print(browser.wd.get_log('browser'), file=sys.stderr)
#atexit.register(at_exit_print_browser_output, browser)
#DesiredCapabilities.CHROME['loggingPrefs'] = {'browser': 'ALL'}
#print(driver.get_log('browser'))

browser_pid = Process(browser.wd.service.process.pid).children()[0].pid
print(browser_pid, flush=True, file=sys.stdout)

def try_until_success(calls, exceptions_max=5):
    success = False
    exceptions = []
    while not success:
        try:
            for call, args in calls:
                call(*args)
        except WebDriverException as we:
            exceptions.append(we)
            if len(exceptions) > exceptions_max:
                print(exceptions, file=sys.stderr)
                raise
        else:
            success = True
        
class Tab:
    def __init__(self, urls):
        if not urls:
            raise ValueError('no urls provided')
        self.urls_visited = []
        self.urls_remaining = list(urls)
        browser.execute_script('window.open()')
        self._bwin = browser.window(handle=browser.wd.window_handles[-1])
        self._iter = iter(self)
        next(self._iter)

    def goto_next_url(self, repeat=1):
        try:
            for _ in range(repeat):
                next(self._iter)
        except StopIteration:
            return False
        else:
            return True

    def close(self):
        self._iter.close()

    def __iter__(self):
        try:
            while self.urls_remaining:
                success = True
                yield
                url = self.urls_remaining.pop()
                # TODO: use try_until_success
                exceptions_max=10; exceptions = 0
                while True:
                    try:
                        self._bwin.use()
                        browser.goto(url)
                    except (WebDriverException, UnexpectedAlertPresentException):
                        exceptions += 1
                        if exceptions > exceptions_max:
                            success = False
                            raise
                        else:
                            sleep(.5)
                    else:
                        break
                self.urls_visited.append(url)
        finally:
            if success:
                self._bwin.unuse()
                self._bwin.close()

tabs = set()
urls_visited = 0
tabs_required = 1
# Randomise tabs_required every tabs_required_randomise_period URLs; save the latest urls_visited
# after an update in tabs_required_randomise_last
#urls_partitioned = [urls]                # Disabled
#tabs_required_randomise_period = 10**9   # Disabled
tabs_required_randomise_period = 50
tabs_required_randomise_last = 0
workload_pause_period = 0
workload_pause_last = 0
while urls_partitioned or tabs:
    if urls_partitioned:
        if len(tabs) < tabs_required:
            for _ in range(len(tabs), min(len(urls_partitioned), tabs_required)):
                tabs.add(Tab(urls_partitioned.pop()))
        elif len(tabs) > tabs_required:
            tabs_to_remove = len(tabs) - tabs_required
            for t in sorted(tabs, key=lambda t: len(t.urls_visited), reverse=True)[:tabs_to_remove]:
                urls_partitioned.append(t.urls_remaining)
                tabs.remove(t)
                t.close()

    for t in list(tabs):
        if not t.goto_next_url(random.choice(range(1, 20))):
            tabs.remove(t)
            urls_visited = urls_visited + len(t.urls_visited)

    if urls_visited >= tabs_required_randomise_last + tabs_required_randomise_period:
        tabs_required = int(tabs_required * random.choice((0.25, 0.5, 2, 4)))
        tabs_required = max(1, min(tabs_required, params.tabs_max))
        tabs_required_randomise_last = urls_visited

    if workload_pause_period > 0 and urls_visited >= workload_pause_last + workload_pause_period:
        sleep(240)
        workload_pause_last = urls_visited

print('OK -- done', file=sys.stderr)
browser.close()

'''
with browser.window(handle=browser.wd.window_handles[0]) as w:
    browser.goto('google.com')
    w.close()
browser.execute_script('window.open()')
with browser.window(handle=browser.wd.window_handles[-1]) as w:
    browser.goto('google.com')
    w.close()

for wh in browser.wd.window_handles:
    w = browser.window(handle=wh)
    with w:
        browser.goto('google.com')
    # also 
    #w.use()
    #browser.goto()

for wh in browser.wd.window_handles:
    w = browser.window(handle=wh)
    with w:
        browser.goto('youtube.com')
    # also 
    #w.use()
    #browser.goto()
'''
