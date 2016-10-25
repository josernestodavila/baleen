require "baleen/error"
require 'forwardable'

module Baleen

  class RunnerManager
    def initialize(connection, task)
      @task       = task
      @connection = connection
    end

    def run
      results = []
      prepare_task
      pool = Runner.pool(size: @task.concurrency, args: [@connection])

      @task.target_files.map { |file|
        file.sub!("rails/", "")
        task = @task.dup
        task.files = file

        pool.future.run(task)
      }.each do |actor|
        results << actor.value
      end

      @task.results = results
      yield @task
    end

    private

    def prepare_task
      @task.prepare
    end
  end

  class Runner
    include Celluloid
    extend Forwardable

    def_delegator :@connection, :notify_info

    def initialize(connection=nil)
      @connection = connection ? connection : Connection.new
    end

    def create_container(task)
      if task.files
        container_name = task.files.gsub('/', '_').split('.').first
      end

      @container  = Docker::Container.create(
          'name' => container_name || nil,
          'Cmd' => ["bash", "-c", task.commands],
          'Image' => task.image,
          'HostConfig' => {
              'Binds' => task.volumes
          })

      @task = task
    end

    def run(task)
      max_retry = 10; count = 0

      create_container(task)

      begin
        notify_info("Start feature #{@task.files} in container #{@container.id}")
        @container.start
        @container.wait(1200) #TODO move to configuration
        notify_info("Finish feature #{@task.files} in container #{@container.id}")

        if @task.commit
          notify_info("Committing the change of container #{@container.id}")
          @container.commit({repo: @task.image}) if @task.commit
        end
      rescue Excon::Errors::NotFound
        count += 1
        if count > max_retry
          raise Baleen::Error::StartContainerFail
        else
          sleep 1
          retry
        end
      rescue Docker::Error::TimeoutError
        notify_info("Kill feature #{@task.files} in container #{@container.id}")
        build_failed = {
          status_code: "1",
          container_id: @container.id,
          stdout: [""],
          stderr: ["Build took too much time."],
          file: @task.files,
        }
        container = @container.kill!
        container.remove

        return build_failed
      end

      stdout, stderr = *@container.attach(:stream => false, :stdout => true, :stderr => true, :logs => true)

      stdout = stdout.map{|e| e.force_encoding(Encoding::UTF_8)}
      stderr = stderr.map{|e| e.force_encoding(Encoding::UTF_8)}

      result = {
        status_code: @container.json["State"]["ExitCode"],
        container_id: @container.id,
        stdout: stdout,
        stderr: stderr,
        file: @task.files,
      }

      @container.remove
      result
    end

  end
end