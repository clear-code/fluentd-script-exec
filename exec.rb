#!/usr/bin/env ruby

require "optparse"
require 'fileutils'
require "date"
require "open3"

def parse_commandline_args(args)
  args = args.dup

  hour = nil
  status_file = nil
  dry_run = false

  parser = OptionParser.new
  parser.banner = <<~BANNER
    Usage: exec.rb "command" [options]
    Example: ruby exec.rb "cat /path/to/file.log" --hour 20 --status-file /path/to/status

  BANNER

  parser.on("--hour HOUR", "Execute collection only at this hour.", "Default: Disabled", Integer) do |v|
    hour = v
  end
  parser.on("--status-file PATH", "Prevent duplicate collecting in the day by keeping the last collecting time in the file.", "Default: Disabled") do |v|
    status_file = v
  end
  parser.on("--dry-run", "For test. The status file is not updated.") do
    dry_run = true
  end

  begin
    parser.parse!(args)
  rescue OptionParser::ParseError => e
    $stderr.puts e
    $stderr.puts parser.help
    return nil
  end

  if hour and (hour < 0 or hour > 23)
    $stderr.puts "--hour #{hour} must be an integer from 0 to 23."
    $stderr.puts parser.help
    return nil
  end

  if args.size == 0
    $stderr.puts "Need the command to exec."
    $stderr.puts parser.help
    return nil
  end
  if args.size > 1
    $stderr.puts "Invalid arguments: #{args[1..]}"
    $stderr.puts parser.help
    return nil
  end

  command = args.first

  return command, hour, status_file, dry_run
end

class Status
  def initialize(status_file)
    @status_file = status_file

    dir = File.dirname(@status_file)
    FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
  end

  def status
    return {} unless File.exist?(@status_file)
    File.open(@status_file, "rb") do |f|
      return Marshal.load(f)
    end
  end

  def update_status(status)
    File.open(@status_file, "wb") do |f|
      Marshal.dump(status, f)
    end
  end

  def last_collection_time
    status["last_collection_time"]
  end

  def update_last_collection_time(last_collection_time)
    current_status = status
    current_status["last_collection_time"] = last_collection_time
    update_status(current_status)
  end
end

def same_date?(time, another)
  time.to_date == another.to_date
end

def exec_command(command, hour, status_file, dry_run)
  current_time = Time.now

  return nil if hour and hour != current_time.hour
  if status_file
    status = Status.new(status_file)
    last_collection_time = status.last_collection_time
    return nil if last_collection_time and same_date?(last_collection_time, current_time)
  end

  standard_o, error_o, ps_status = Open3.capture3(command)
  $stderr.puts "'#{command}' exited with return-code: #{ps_status.exitstatus}" unless ps_status.success?
  $stderr.puts error_o unless error_o.empty?

  unless dry_run
    status.update_last_collection_time(current_time) if status_file
  end

  standard_o
end

if __FILE__ == $PROGRAM_NAME
  args = parse_commandline_args(ARGV)
  exit 1 unless args

  content = exec_command(*args)
  print content if content
end
