require 'minitest/autorun'
require 'orocos/test/component'
require 'minitest/spec'
require 'rock/gazebo'

module Helpers
    def setup
        Orocos.initialize if !Orocos.initialized?
        @gazebo_output = Tempfile.open 'rock_gazebo'
        Rock::Gazebo.model_path = [File.expand_path('models', __dir__)]
    end

    def teardown
        if !passed?
            @gazebo_output.rewind
            puts @gazebo_output.read
        end

        if @gazebo_pid
            begin
                Process.kill 'INT', @gazebo_pid
                Process.waitpid @gazebo_pid
            rescue Errno::ESRCH, Errno::ECHILD
            end
        end
        @gazebo_output.close
    end

    def expand_fixture_world(path)
        fixture_world_dir = File.expand_path('worlds', __dir__)
        return File.expand_path(path, fixture_world_dir)
    end

    def expand_fixture_model(name)
        File.expand_path(File.join(name, 'model.sdf'),
                         File.join(__dir__, 'models'))
    end
 
    def gzserver(world_file, expected_task_name, timeout: 10)
        @gazebo_pid = Rock::Gazebo.spawn(
            'gzserver', expand_fixture_world(world_file), '--verbose', '--model-dir', File.join(__dir__, 'models'),
            out: @gazebo_output,
            err: @gazebo_output)

        deadline = Time.now + timeout
        begin
            sleep 0.01
            begin return Orocos.get(expected_task_name)
            rescue Orocos::NotFound
            end
            begin
                if status = Process.waitpid(@gazebo_pid, Process::WNOHANG)
                    gazebo_flunk("gzserver terminated before '#{expected_task_name}' could be reached")
                end
            rescue Errno::ECHILD
                gazebo_flunk("gzserver failed to start")
            end
        end while Time.now < deadline
        gazebo_flunk("failed to gazebo_reach task '#{expected_task_name}' within #{timeout} seconds, available tasks: #{Orocos.name_service.names.join(", ")}")
    end

    def gazebo_flunk(message)
        @gazebo_output.rewind
        puts @gazebo_output.read
        flunk(message)
    end

    def matrix3_rand
        values = (0...9).map { rand.abs }
        Types.base.Matrix3d.new(data: values)
    end

    def assert_matrix3_in_delta(expected, actual, delta = 1e-9)
        9.times do |i|
            assert_in_delta expected.data[i], actual.data[i], delta, "element #{i} differs by more than #{delta}"
        end
    end

    def poll_until(timeout: 5, period: 0.01, message: 'could not reach condition')
        start = Time.now
        while (Time.now - start) < timeout
            return if yield
            sleep(period)
        end
        flunk(message)
    end
end


class Minitest::Test
    include Helpers
end
