# fluentd-script-exec

A script to run a command and return the standart output.
This script is intended to be used in [in_exec](https://docs.fluentd.org/input/exec) of [Fluentd](https://www.fluentd.org/).

## Usage

### Options

```console
$ ruby exec.rb --help
Usage: exec.rb path [options]
Example: ruby exec.rb /path/to/file.log --hour 20 --status-file /path/to/status
Example: ruby exec.rb /path/to/file.log --hour 20 --move

        --encoding ENCODING          Encoding of the file to collect, such as utf-8, shift_jis.
                                     Default: shift_jis
        --hour HOUR                  Execute collection only at this hour.
                                     Default: Disabled
        --move                       Move the file after collecting to prevent duplicate collecting by adding `.collected` extension.
                                     Default: Disabled
        --status-file PATH           Prevent duplicate collecting in the day by keeping the last collecting time in the file.
                                     Default: Disabled
        --dry-run                    For test. The file is not moved and the status file is not updated.
```

### With in_exec of Fluentd

Collect an entire file daily at around 20:00 ~ 20:59.

```xml
<source>
  @type exec
  @id in_exec
  tag test
  command "/opt/fluent/bin/ruby /path/exec.rb /path/target.log --encoding utf-8 --hour 20 --status-file /path/status"
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
