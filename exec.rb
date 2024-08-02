#!/usr/bin/env ruby

require "optparse"
require 'fileutils'
require "date"

def parse_commandline_args(args)
  args = args.dup

  encoding = "shift_jis"
  hour = nil
  move = false
  status_file = nil
  dry_run = false

  parser = OptionParser.new
  parser.banner = <<~BANNER
    Usage: exec.rb path [options]
    Example: ruby exec.rb /path/to/file.log --hour 20 --status-file /path/to/status
    Example: ruby exec.rb /path/to/file.log --hour 20 --move

  BANNER
  parser.on("--encoding ENCODING", "Encoding of the file to collect, such as utf-8, shift_jis.", "Default: #{encoding}") do |v|
    encoding = v
  end
  parser.on("--hour HOUR", "Execute collection only at this hour.", "Default: Disabled", Integer) do |v|
    hour = v
  end
  parser.on("--move", "Move the file after collecting to prevent duplicate collecting by adding `.collected` extension.", "Default: Disabled") do
    move = true
  end
  parser.on("--status-file PATH", "Prevent duplicate collecting in the day by keeping the last collecting time in the file.", "Default: Disabled") do |v|
    status_file = v
  end
  parser.on("--dry-run", "For test. The file is not moved and the status file is not updated.") do
    dry_run = true
  end

  begin
    parser.parse!(args)
  rescue OptionParser::ParseError => e
    $stderr.puts e
    $stderr.puts parser.help
    return nil
  end

  begin
    Encoding.find(encoding)
  rescue ArgumentError => e
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
    $stderr.puts "Need the filepath to collect."
    $stderr.puts parser.help
    return nil
  end
  if args.size > 1
    $stderr.puts "Invalid arguments: #{args[1..]}"
    $stderr.puts parser.help
    return nil
  end

  path = args.first

  return path, encoding, hour, move, status_file, dry_run
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

def read(path, encoding, hour, move, status_file, dry_run)
  current_time = Time.now

  return nil if hour and hour != current_time.hour
  if status_file
    status = Status.new(status_file)
    last_collection_time = status.last_collection_time
    return nil if last_collection_time and same_date?(last_collection_time, current_time)
  end

  return nil unless File.exist?(path)

  content = File.read(path, mode: "r", encoding: encoding)

  unless dry_run
    if move
      FileUtils.mv(path, path + '.collected')
    end

    status.update_last_collection_time(current_time) if status_file
  end

  content
end

if __FILE__ == $PROGRAM_NAME
  args = parse_commandline_args(ARGV)
  exit 1 unless args

  content = read(*args)
  print content if content
end
