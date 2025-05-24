import collections
import functools
import io
import logging
import sys
import unicodedata as unicode
import time

from .logger import Logger, LEVELS

LOG_RETENTION = 30000
LOGGER_FORMAT = ('%(asctime)s [%(levelname)8s] '
                 '%(name)s[%(filename)s:%(funcName)s:%(lineno)d]: '
                 '%(message)s')
LOGGER = Logger()
logger = logging.getLogger(__name__)
# to print to stdout the lines we add SummaryFilter to a stdout handler:
#   log.info("message', extra=SUMMARY)
SUMMARY = dict(summary=True)

try:
    unicode
except NameError:
    unicode = str  # pylint: disable=invalid-name,redefined-builtin


def configure_log_levels(log_level):
    """Assign log-levels per named logger from csv name=level[,name=level]*
    e.g: requests=ERROR,vmware.common=WARNING,vmware.common.foo=DEBUG
    """
    if not log_level:
        log_level = "INFO"
    for per_logger in log_level.split(","):
        if not per_logger:
            # Empty section
            continue
        if "=" in per_logger:
            # This config has logger name
            logger_id, level = per_logger.split("=", 1)
        else:
            # This is setting for the root logger
            logger_id = ""
            level = per_logger
        assert level in LEVELS, (
            "Unknown log level '%s', supported levels are: %s" %
            (level, ", ".join(LEVELS)))
        logging.getLogger(logger_id).setLevel(LEVELS[level])


class TruncatingStream(io.IOBase):
    def __init__(self, line_count=LOG_RETENTION, line_ending="\n"):
        io.IOBase.__init__(self)
        self._line_ending = unicode(line_ending)
        self._lines = collections.deque(maxlen=line_count)

    def write(self, data):
        new_lines = str(data).split(self._line_ending)
        for line in new_lines:
            # Skip empty lines
            if not line:
                continue
            self._lines.append(line)

    def getvalue(self):
        return self._line_ending.join(self._lines)

    def close(self):
        self._lines = None


class SummaryFilter(logging.Filter):
    """Filters out all but messages that should be displayed in summary.
    """
    # pylint:disable=R0903

    def filter(self, record):
        if record.levelno >= logging.WARNING:
            return True
        return getattr(record, "summary", False)


def log_call(msg='calling', level='info', response_level=None, extra=None):
    """ Decorator boilerplate for logging a function call. as this is a simple decorator, please
    dont add args and kwargs here, but if desired add a debug message inside the called
    function.

    Log messages are sent to stdout if extra=SUMMARY.

    Args:
        level: a method name on logger matching level of log-message desired
        response_level: a method name on logger matching level of log-message desired if a response
                        log message is desired
        extra: used by decorator @summary for signalling to SummaryFilter

    usage:
        @log_call()
        def foo(id, was):      > calling foo
            ...
        @log_call(msg='good ide')
        def foo(id, was):      > good idea foo
            ...
        @log_call(response_level='debug')
        def foo(id, was):      > returned from foo response: True
            return True
        @log_call(msg='predicate', response_level='debug')
        def bar(id, was):      > predicate bar()
                               > returned from bar() response: False
            return False
    """

    def decorator(func):
        module = sys.modules[func.__module__]
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            # try to use the caller's logger if its got a well known name
            log = getattr(module, 'logger', None) or logger
            log_method = getattr(log, level, None) or log.info
            log_method(f"{msg} {func.__name__}()", extra=extra)
            response = func(*args, **kwargs)
            if response_level:
                _log_method = getattr(log, response_level, None) or log_method
                _log_method(f"returned from {func.__name__}() response: {response}", extra=extra)
            return response

        return wrapper
    return decorator


# wrap functins with @summary for log messages to show on console
summary = functools.partial(log_call, extra=SUMMARY)


def add_root_handler(handler, dupes_ok=False):
    """Adds a given handler to the root logger. it seems unlikely that multiple-same classes
    are desired as handlers, so we remove extand handlers of the same class if not dupes_ok.
    """
    root_logger = logging.getLogger()
    if not dupes_ok:
        doomed = []
        for h in root_logger.handlers:
            if h.__class__ is handler.__class__:
                doomed.append(h)
        for h in doomed:
            root_logger.removeHandler(h)

    root_logger.addHandler(handler)


def add_summary_log_filter(logger=None, handler=None, log_format=LOGGER_FORMAT):
    """Setup stdout logging as pure summary, if handler is provided we accept it as target and
    add SummaryFilter to that.
    """
    logger = logger or logging.getLogger()
    if handler is None:
        handler = logging.StreamHandler(sys.stdout)
        add_root_handler(handler)
    formatter = logging.Formatter(log_format)
    formatter.converter = time.gmtime
    handler.setFormatter(formatter)
    handler.addFilter(SummaryFilter())
