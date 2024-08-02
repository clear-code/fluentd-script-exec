# fluentd-script-exec

A script to run a command and return the standart output.
This script is intended to be used in [in_exec](https://docs.fluentd.org/input/exec) of [Fluentd](https://www.fluentd.org/).

## Usage

### Options

```console
$ ruby exec.rb --help
Usage: exec.rb "command" [options]
Example: ruby exec.rb "cat /path/to/file.log" --hour 20 --status-file /path/to/status

        --hour HOUR                  Execute collection only at this hour.
                                     Default: Disabled
        --status-file PATH           Prevent duplicate collecting in the day by keeping the last collecting time in the file.
                                     Default: Disabled
        --encoding ENCODING          Encoding of the output of the command. If specified, the standart output will be converted to utf-8 from this encoding.
                                     Default: Disabled
        --dry-run                    For test. The status file is not updated.
```

### With in_exec of Fluentd

Run the command and read the standard output daily at around 20:00 ~ 20:59.

```xml
<source>
  @type exec
  @id in_exec
  tag test
  command "/opt/fluent/bin/ruby /path/exec.rb "command -a xxx -b xxx" --hour 20 --status-file /path/status"
  run_interval 15m
  <parse>
    @type none
  </parse>
</source>
```

## Test

```console
$ rake
```

## Copyright

* Copyright(c) 2024 Fukuda Daijiro
* License
  * Apache License, Version 2.0
