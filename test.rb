require "test-unit"
require_relative "exec"
require 'tmpdir'
require 'pathname'
require 'timecop'
require "open3"

class ParseCommandlineArgsTest < Test::Unit::TestCase
  data(
    "Minimum",
    [
      ["/path/to/file.log"],
      ["/path/to/file.log", nil, nil, nil, false]
    ]
  )
  data(
    "Full",
    [
      ["/path/to/file.log", "--hour", "20", "--status-file", "/path/to/status", "--encoding", "shift_jis", "--dry-run"],
      ["/path/to/file.log", 20, "/path/to/status", "shift_jis", true]
    ]
  )
  test "Can parse correct args" do |(args, expected_results)|
    results = parse_commandline_args(args)
    assert_equal expected_results, results
  end

  data("No args", [])
  data("Invalid hour: not integer", ["/path/to/file.log", "--hour", "not integer"])
  data("Invalid hour: wrong integer", ["/path/to/file.log", "--hour", "24"])
  data("Invalid encoding", ["/path/to/file.log", "--encoding", "invalid encoding name"])
  data("Unassumed args 2", ["/path/to/file.log", "unassumed arg"])
  test "Return nil for invalid args" do |args|
    results = parse_commandline_args(args)
    assert_nil results
  end
end

class ReadTest < Test::Unit::TestCase
  def setup
    Dir.mktmpdir do |tmp_dir|
      @tmp_dir = Pathname(tmp_dir)
      yield
    end
  end

  def make_testfile(path, content, **args)
    File.open(path, "w", **args) do |f|
      f.puts content
    end
  end

  def command_to_read_file(path)
    if /linux/ === RUBY_PLATFORM or /darwin/ =~ RUBY_PLATFORM
      "cat #{path.to_s}"
    else
      "type #{path.to_s.gsub("/", "\\")}"
    end
  end

  test "read" do
    filepath = @tmp_dir + "test"
    content = <<~CONTENT
      testlog1
      testlog2
    CONTENT
    make_testfile(filepath, content)

    result, status = Open3.capture2e("ruby", "exec.rb", command_to_read_file(filepath))

    assert_equal 0, status.exitstatus
    assert_equal content, result
  end

  test "Can read shift_jis file with minimum args" do
    filepath = @tmp_dir + "test"
    content = <<~CONTENT
      sample log
      日本語のログ
    CONTENT
    make_testfile(filepath, content, encoding: "shift_jis")

    result, status = Open3.capture2e("ruby", "exec.rb", command_to_read_file(filepath))

    assert_equal(
      [0, content],
      [status.exitstatus, result.encode("utf-8", "shift_jis")]
    )
  end

  test "Can read shift_jis file with encoding option" do
    filepath = @tmp_dir + "test"
    content = <<~CONTENT
      sample log
      日本語のログ
    CONTENT
    make_testfile(filepath, content, encoding: "shift_jis")

    result, status = Open3.capture2e("ruby", "exec.rb", command_to_read_file(filepath), "--encoding", "shift_jis")

    assert_equal(
      [0, content],
      [status.exitstatus, result]
    )
  end

  test "Can read utf-8 file" do
    filepath = @tmp_dir + "test"
    content = <<~CONTENT
      sample log
      日本語のログ
    CONTENT
    make_testfile(filepath, content, encoding: "utf-8")

    result, status = Open3.capture2e("ruby", "exec.rb", command_to_read_file(filepath))

    assert_equal(
      [0, content],
      [status.exitstatus, result]
    )
  end

  test "Can read file with hour" do
    filepath = @tmp_dir + "test"
    content = <<~CONTENT
      sample log
      日本語のログ
    CONTENT
    make_testfile(filepath, content)

    Timecop.freeze(2024, 7, 9, 0, 0, 0) do
      result = exec_command(command_to_read_file(filepath), 20, nil, nil, false)
      assert_nil result
    end

    Timecop.freeze(2024, 7, 9, 20, 0, 0) do
      result = exec_command(command_to_read_file(filepath), 20, nil, nil, false)
      assert_equal content, result
    end
  end

  test "Can read file with status" do
    filepath = @tmp_dir + "test"
    status_path = @tmp_dir + "status"
    content = <<~CONTENT
      sample log
      日本語のログ
    CONTENT
    make_testfile(filepath, content)

    Timecop.freeze(2024, 7, 9, 20, 0, 0) do
      result = exec_command(command_to_read_file(filepath), 20, status_path.to_s, nil, false)
      assert_equal content, result
    end
    Timecop.freeze(2024, 7, 9, 20, 59, 59) do
      result = exec_command(command_to_read_file(filepath), 20, status_path.to_s, nil, false)
      assert_nil result
    end
    Timecop.freeze(2024, 7, 10, 0, 0, 0) do
      result = exec_command(command_to_read_file(filepath), 20, status_path.to_s, nil, false)
      assert_nil result
    end
    Timecop.freeze(2024, 7, 10, 20, 0, 0) do
      result = exec_command(command_to_read_file(filepath), 20, status_path.to_s, nil, false)
      assert_equal content, result
    end
  end

  test "dry-run does not update the status file" do
    filepath = @tmp_dir + "test"
    status_path = @tmp_dir + "status"
    content = <<~CONTENT
      sample log
      日本語のログ
    CONTENT
    make_testfile(filepath, content, encoding: "shift_jis")

    result, status = Open3.capture2e("ruby", "exec.rb", command_to_read_file(filepath), "--status-file", status_path.to_s, "--dry-run")

    assert_equal(
      [0, content, false],
      [status.exitstatus, result.encode("utf-8", "shift_jis"), File.exist?(status_path)]
    )
  end

  test "Retry when the command fails" do
    filepath = @tmp_dir + "test"
    status_path = @tmp_dir + "status"
    error_path = @tmp_dir + "error.log"
    content = <<~CONTENT
      sample log
      日本語のログ
    CONTENT
    make_testfile(filepath, content)

    command_to_succeed = "ruby exec.rb \"#{command_to_read_file(filepath)}\" --status-file #{status_path.to_s} 2> #{error_path.to_s}"
    command_to_fail = "ruby exec.rb \"#{command_to_read_file(filepath + 'wrong-path')}\" --status-file #{status_path.to_s} 2> #{error_path.to_s}"

    result, status = Open3.capture2e(command_to_fail)
    assert_equal(
      ["", 0],
      [result, status.exitstatus]
    )
    assert do
      not File.read(error_path).empty?
    end

    result, status = Open3.capture2e(command_to_succeed)
    assert_equal(
      [content, 0],
      [result, status.exitstatus]
    )
    assert do
      File.read(error_path).empty?
    end
  end
end
