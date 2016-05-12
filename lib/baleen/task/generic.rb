require "baleen/task/task"

module Baleen
  module Task
    class Generic < Baleen::Task::Base

      def initialize(opt)
        super()
        @params[:work_dir]       = opt[:work_dir]    ||="./"
        @params[:run_dir]        = opt[:run_dir]     ||=@params[:work_dir]
        @params[:image]          = opt[:image]
        @params[:command]        = opt[:command]
        @params[:volumes]        = opt[:volumes]     ||=[]
      end
    end
  end
end