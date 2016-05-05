import sys

class Args:
    def __init__(self):
        self.map = dict()

    def add(self, opts, arg):
        for opt in opts:
            self.map[opt] = arg
        if arg[1] == 'bool':
            self.__dict__[arg[0]] = arg[2]
    
    def parse(self, argv):
        try:
            i = 1
            while i < len(argv):
                (option, type, default) = self.map[argv[i]]
                if type == 'string':
                    i += 1
                    self.__dict__[option] = argv[i]
                elif type == 'integer':
                    i += 1
                    self.__dict__[option] = int(argv[i])
                elif type == 'bool':
                    self.__dict__[option] = True
                i += 1
        except Exception:
            args = dict()
            args_hint = ''
            
            for cli_opt, (option, type, default) in self.map.items():
                if option not in args:
                    args[option] = ([cli_opt], type)
                else:
                    args[option][0].append(cli_opt)
            
            for option, (cli_opts, type) in args.items():
                cli_opts_str = cli_opts[0]
                i = 1
                while i < len(cli_opts):
                    cli_opts_str += ' | {}'.format(cli_opts[i])
                    i += 1
                args_hint += '[{}{}] '.format(cli_opts_str, '' if type == 'bool' else ' <{}>'.format(option.upper()))

            print('Usage: {} {}'.format(argv[0], args_hint), file=sys.stderr)
            exit(1)

        for opt, type, default in self.map.values():
            if opt not in self.__dict__:
                self.__dict__[opt] = default
