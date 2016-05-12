require "baleen/task/task"

module Baleen
  module Task
    class Cucumber < Baleen::Task::Base

      include Serializable
      include Baleen::Default

      attr_reader :target_files

      def initialize(opt)
        super()
        @params[:bin]            = opt[:bin]            || "bundle exec cucumber"
        @params[:options]        = opt[:options]
        @params[:work_dir]       = opt[:work_dir]       || default_work_dir
        @params[:run_dir]        = opt[:run_dir]        || opt[:work_dir] || default_work_dir
        @params[:files]          = opt[:files]          || default_features
        @params[:concurrency]    = opt[:concurrency]    || default_concurrency
        @params[:before_command] = opt[:before_command] || default_before_command
        @params[:image]          = opt[:image]
        @params[:command]        = opt[:command]
        @params[:results]        = opt[:results]
        @params[:status]         = opt[:status]
        @params[:commit]         = nil
        @params[:volumes]        = opt[:volumes]        || []
      end

      def prepare
        task = Generic.new(
          work_dir: work_dir,
          image:    image,
          command:  %{find #{files} | grep "\\.feature"},
          volumes:  volumes
        )
        runner = Baleen::Runner.new
        result = runner.run(task)
        @target_files = result[:stdout]
      end

    end

  end
end