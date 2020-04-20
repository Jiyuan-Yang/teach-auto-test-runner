class AutoTestController < ApplicationController
  include AutoTestHelper

  # skip CSRF check
  skip_before_action :verify_authenticity_token, only: [
      :create_auto_test_point,
      :start_auto_test,
      :get_auto_test_results
  ]

  def create_auto_test_point
    @auto_test_point = AutoTestPoint.new
    @auto_test_point.project_id = params[:project_id]
    @auto_test_point.input = params[:input]
    @auto_test_point.expected_output = params[:expected_output]
    @auto_test_point.save
    auto_test_point_id = AutoTestPoint.last.id
    render json: {:auto_test_point_id => auto_test_point_id, :status => 'Okay'}
  end

  def start_auto_test
    project_id = params[:project_id].to_i
    # use `,` to split
    # todo: here we use http to clone, consider to use SSH later
    git_repo_list = params[:git_repo_list].split(',')
    # check if there is a directory for this project, if not, create it
    project_dir_initializer(project_id)
    git_pull_projects(project_id, git_repo_list)
  end

  def get_auto_test_results

  end
end
