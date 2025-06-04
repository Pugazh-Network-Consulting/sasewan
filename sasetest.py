""" Command line tool module to create 3-site topology """
import argparse
import sys

from logger import LOGGER
from tools import kvm_tool

def convert_arg_line_to_args(arg_line):
    for arg in arg_line.split():
        if not arg.strip():
            continue
        yield arg


class saseTest(object):
    """ saseTest class.

    saseTest class is the main function to create the base test bed to run various tests 
    """

    def __init__(self):
        """ Initializer for CLI class """

        self.help = "Various Commands to run SaseTest Suites"
        parser = argparse.ArgumentParser(description="Welcome to SaseTest CLI tool")
        parser.fromfile_prefix_chars = '@'
        parser.convert_arg_line_to_args = convert_arg_line_to_args
        self.main_parser = parser

        build = [
            {
                "name": "kvm",
                "help": "Tool to create KVM topology on Private/Public Cloud Infrastructure",
                "add_args": kvm_tool.add_args,
                "processor": kvm_tool.build
            },
        ]
        destroy = [
           {
                "name": "kvm",
                "help": "Tool to destroy KVM topology on Private/Public Cloud Infrastructure",
                "add_args": kvm_tool.add_args,
                "processor": kvm_tool.destroy
            },
        ]
        self.function_list = [
            {
                "name": "build",
                "help": "Tool to Build a topology",
                "description": "Build various types of topology to run Sase Test Suite",
                "subparsers": build,
                "add_args": "kvm scale" #[ "kvm", "scale" ]
            },
            {
                "name": "destroy",
                "help": "Tool to Destroy a topology",
                "description": "Destroy various types of topology which are created using Sasetests script ",
                "subparsers": destroy,
                "add_args": "kvm scale" #[ "kvm", "scale" ]
            },
        ]
        
        self.subparser_objects = {}
        self.processor = {"default": self.default_processor}
        self.log = LOGGER.log

    @classmethod
    def default_args(cls, parser):
        """ Default arguments which will be add to all parsers.

        Args:
            parser(argparse.ArgumentParser): parser instance.
        """

        parser.add_argument("--log-level",
                            required=False, default="INFO",
                            action="store",
                            help="Logging level: 'DEBUG', 'INFO', 'CRITICAL'")
        parser.add_argument("--log-file", required=False, action="store", default=sys.stdout,
                            help="Logfile name to store console output to a file")

    def form(self):
        """ Form the whole sasetest cli tool. """

        subparsers = self.main_parser.add_subparsers(help=self.help, dest="subparser_name")
        for function in self.function_list:
            # For forming subsubparsers 
            if "subparsers" in function:
                subparser = subparsers.add_parser(function["name"], help=function["help"])
                self.subparser_objects[function["name"]] = subparser
                sub_parser = Parser(subparser, function["subparsers"], function["description"])
                sub_parser.gen_parser()
                for subsubparser in sub_parser.subparser_list:
                    self.default_args(subsubparser)
                self.processor[function["name"]] = sub_parser.processors
            # For forming subparsers like which dont use subsubparser
            else:
                subparser = subparsers.add_parser(function["name"], help=function["help"])
                if function["add_args"]:
                    function["add_args"](subparser)
                self.processor[function["name"]] = function["processor"]
                self.default_args(subparser)

    def run(self):
        """ Run the sasetest cli tool. """
        args = self.main_parser.parse_args()
        self.processor["default"](args)

        if args.subparser_name:
            if hasattr(args, "subsubparser_name") and args.subsubparser_name:
                self.processor[args.subparser_name][args.subsubparser_name](args)
            elif (len(args.__dict__) == 2 and [function["add_args"] for function in self.function_list if function["name"] == args.subparser_name][0]):
                self.subparser_objects[args.subparser_name].print_help()
            else:
                self.processor[args.subparser_name](args)

    def default_processor(self, args):
        """ Default processor, to extend sase cli supporting default arguments.

        Args:
            args(argparse.Args object): arguments.
        """

        if (hasattr(args, "log_level") and
                args.log_level and args.log_level.upper() in ["INFO", "DEBUG", "CRITICAL"]):
            self.log.setLevel(args.log_level.upper())
        #if args.log_file:
        if (hasattr(args, "log_file")):
            LOGGER.cleanup_sys_out()
            LOGGER.setup(args.log_file, self.log.name, {"level": args.log_level.upper()})
        args_dict = args.__dict__.copy()
        args_dict.pop("subparser_name")
        if not args_dict:
            self.main_parser.print_help()


class Parser(object):
    """ Sasetest Command line tool class.

        This class is for simplifying generating parser with multiple subparsers.
    """

    def __init__(self, parser, tools, description=""):
        """ Init method of Parser.

        Args:
            parser(argparse.ArgumentParser): parser instance as parent parser.
            tools (dict): dict contains method of add_args and processor.
            description (str): description of the parser.
        """

        self.parser = parser
        self.subparsers = self.parser.add_subparsers(
            help=description, dest="subsubparser_name")

        self.subparser_list = []
        self.tools = tools
        self.processors = {}

    def _add_subparser(self, name, add_args, help_str):
        """ Add subparser to sase cli.

        Args:
            name (str): subparser name.
            add_args (method or list of methods): method or list of methods to add arguments.
            help_str (str): help string.
        """

        subparser = self.subparsers.add_parser(name, help=help_str)
        if isinstance(add_args, list):
            for method in add_args:
                method(subparser)
        else:
            add_args(subparser)

        self.subparser_list.append(subparser)

    def _add_processor(self, name, processor):
        """ Add processor to related subparser name.

        Args:
            name (str): subparser name.
            processor (method): method to process with arguments.
        """

        self.processors[name] = processor

    def gen_parser(self):
        """ Generate the whole parser. """

        for tool in self.tools:
            self._add_subparser(tool["name"], tool["add_args"], tool["help"])
            self._add_processor(tool["name"], tool["processor"])
            if "groups" in tool:
                for group in tool["groups"]:  # Add groups to the latest parser created
                    print(group)
                    group["add_args"](self.subparser_list[-1].add_argument_group(group["name"], group["help"]))

    def __str__(self):
        return self.__class__.__name__

def main():
    """ Main function to run this script directly. """
    ft = saseTest()
    ft.form()
    ft.run()

if __name__ == "__main__":
    main()
