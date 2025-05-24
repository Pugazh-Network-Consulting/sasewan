import re
import os
import sys
import atexit
import logging
import itertools
from typing import TextIO
import time


LEVELS = {
    "CRITICAL": logging.CRITICAL,
    "ERROR": logging.ERROR,
    "WARNING": logging.WARNING,
    "INFO": logging.INFO,
    "DEBUG": logging.DEBUG,
    "NOTSET": logging.NOTSET
}


class Logger():
    """ Singleton logger class

    Logs any event to the test case/method file as well as to the sysout.

    Attributes:
        log (logging object): instance of the logging class
    """

    _instance = None
    LOGGER_FORMAT = (
        '%(asctime)s:%(name)s[%(filename)s:%(funcName)s:%(lineno)d]:%(levelname)s:%(message)s'
    )

    @property
    def log(self):
        return self.__log

    def __init__(self):
        """ Initializes a basic instance. """
        logger = self.get_logger()
        self.__log = logger
        self.__log_id = None
        self.setup_sys_out()
        atexit.register(self.cleanup_sys_out)
        self.__log_file_path = None

    def __new__(cls, *args, **kwargs):
        """ Ensures that only one instance of the class is created. """
        if not cls._instance:
            cls._instance = super(Logger, cls).__new__(cls, *args, **kwargs)
        return cls._instance

    @staticmethod
    def get_logger(name='py.test'):
        """Replacement for logging.getLogger which extends the Logger API.

        Args:
            name(str): name of the logger

        Returns:
            logging.Logger object
        """

        logger = logging.getLogger(name)
        # Add a pseudo-method to print an exception stack trace under debug logging.
        setattr(logger, 'debug_exception', _DebugException(logger))
        return logger

    def setup(self, log_file_path, log_name, config):
        """ Sets up the test case/method specific logger instance

        Args:
            log_file_path (str): Path to file name where logger writes in to
            log_name (str): name of the test module
            config (dict): logger configuration with a key named "level"

        Returns:
            Attribute log of the calling instance
        """

        self.__log_file_path = log_file_path
        if not (type(self.__log_file_path) == str):
            self.__log_stream_id = LogStream.register_sys_out(logger=self.log,
                                                         logger_format=self.LOGGER_FORMAT)
        else:
            self.__log_stream_id = LogStream.register_stream(logger=self.log,
                                                         stream=open(log_file_path, 'w+'),
                                                         logger_format=self.LOGGER_FORMAT)
        self.log.name = log_name
        self.log.setLevel(config["level"])
        return self.log

    def cleanup(self):
        """ Cleans up the logger at the end of each test case/method. """
        LogStream.unregister(logger=self.log, _id=self.__log_stream_id)

    def setup_sys_out(self, log_name='flexitest', log_level='CRITICAL'):
        """ Setup default handler as sys out.

        Args:
            log_name (str): name of the test module
            log_level (str): log level.

        Returns:
            Attribute log of the calling instance
        """

        self.__log_sys_out_id = LogStream.register_sys_out(logger=self.log,
                                                           logger_format=self.LOGGER_FORMAT)
        self.log.name = log_name
        self.log.setLevel(log_level)
        return self.log

    def cleanup_sys_out(self):
        """ Clean up the default logger handler. """

        LogStream.unregister(logger=self.log, _id=self.__log_sys_out_id)

    def add_log_stream(self, log_name, mode='ab', share_log_file_path=True):
        """ Create an extra file for logging.

        Args:
            log_name (str): name of log, used as file name.
            mode (str): mode to open file, same as python built-in method open.
            share_log_file_path (bool): create a file in same path setted in setup.

        Returns:
            A corresponding file object.
        """

        if share_log_file_path and self.__log_file_path:
            if self.__log_file_path.endswith('.log'):
                filedir = self.__log_file_path[:-4]
            else:
                filedir = self.__log_file_path
            filename = os.path.join(filedir, log_name + '.log')
            if not os.path.isdir(filedir):
                os.makedirs(filedir)
            return open(filename, mode)
        # if share_log_file_path is False, a log file would be created there itself.
        if log_name.endswith('.log'):
            return open(log_name, mode)
        return open(log_name + '.log', mode)

    def add_independent_logger(self, log_name, level=logging.DEBUG,
                               logger_format='%(levelname)s:%(message)s', mode='ab',
                               share_log_file_path=True):
        """ Create an independent logger.

        Args:
            log_name (str): name of log, used as file name.
            log_level (str): log level.
            logger_format (str): formatting pattern of the log messages
            mode (str): mode to open file, same as python built-in method open.
            share_log_file_path (bool): create a file in same path setted in setup.

        Returns:
            logging.Logger: Logger object which binds file stream.
        """

        logger = logging.getLogger(log_name)
        stream = self.add_log_stream(log_name, mode, share_log_file_path)
        LogStream.register_stream(logger=logger, stream=stream, logger_format=logger_format)
        logger.setLevel(level)
        return logger


class LogStream(object):
    """Registers a stream so that it receives log messages, one per process call. """

    __STREAMS = {}
    __ID = itertools.count()

    @classmethod
    def register_stream(cls, logger, stream, logger_format):
        """ Registers a stream so that it receives log messages, one per process call.

        Args:
            logger (logging object): logging object to which the handlers need to be registered
            stream (file object): stream like object to receive log messages.
            logger_format (str): formatting pattern of the log messages

        Returns:
            id as an integer that can be used by unregister
        """

        file_handler = logging.StreamHandler(stream)
        file_handler.setFormatter(logging.Formatter(logger_format))

        logger.addHandler(file_handler)
        _id = next(cls.__ID)
        cls.__STREAMS[_id] = file_handler
        return _id

    @classmethod
    def register_sys_out(cls, logger, logger_format):
        """ Registers a stream so that it receives log messages, one per process call.

        Args:
            logger (logging object): logging object to which the handlers need to be registered
            stream (file object): stream like object to receive log messages.
            logger_format (str): formatting pattern of the log messages

        Returns:
            id as an integer that can be used by unregister
        """
        sys_out_handler = logging.StreamHandler(sys.stdout)
        sys_out_handler.setFormatter(logging.Formatter(logger_format))

        logger.addHandler(sys_out_handler)
        _id = next(cls.__ID)
        cls.__STREAMS[_id] = sys_out_handler
        return _id

    @classmethod
    def unregister(cls, logger, _id):
        """ Removes the stream associated with the id, which originated from Register.

        Calling this function with the same ID and scope is idempotent.

        Args:
            logger (logging object): logging object to which the handlers need to be unregistered
            _id (int): id previously returned by Register
        """
        handler = cls.__STREAMS.get(_id)
        if handler:
            del cls.__STREAMS[_id]
            logger.removeHandler(handler)


class _DebugException(object):
    """ Pseudo-method that logs an exception stack trace, but only if we're at DEBUG level."""

    def __init__(self, logger):
        """ Initializes a _DebugException object.

        Args:
            logger (logging object): logging.Logger object
        """
        self.__logger = logger

    def __call__(self, exc):
        """ Logs the stack trace of an exception when DEBUG logging is enabled.

        Args:
            exc(exception object): Exception object
        """
        if self.__logger.getEffectiveLevel() <= logging.DEBUG:
            self.__logger.exception(exc)


class TimestampedFile(object):
    """ Creates a timestamped file -- class that prepends the timestamp to each line of a file. """

    def __init__(self, file):
        """ Initialises a timestamped file.

        Args:
            file (File): file object
        """

        self.file = file

    def write(self, data):
        """ Method that writes to a file adding a timestamp to the beginning of each line.

        Args:
            data (str): data to write to the file object of the timestamped file.

        Returns:
            int: number of characters written to the file object.
        """

        timestamp_string = "\n[{}] ".format(time.asctime())
        string = re.sub(r"(\r|\n)+", timestamp_string, data.decode("utf-8", "ignore"))
        return self.file.write(string)

    def flush(self):
        """ Flush the data of the file """

        self.file.flush()

    def __eq__(self, other):
        """ Compares the Timestamped object with another object.

        Args:
            other (Object): Object to compare with.

        Returns:
            bool: True if other is also a TimestampedFile object; False otherwise.
        """

        return self.__class__ == other.__class__
