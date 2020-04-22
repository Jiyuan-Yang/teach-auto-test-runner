=begin
      in this comment, I will describe the workflow for user to compile, run and test project
      1. in HTTP post to request the start_auto_test method, user need to config some params
        Attribute	            Type	      Required	    Description
        target_env            string      no            default is origin ubuntu env, user can ask admin to
                                                        create new env to run their project. Now, I think we
                                                        can give each env an unique id or name.
        instrument_list       string      yes           a series of bash command to compile and run project.

        input_type            string      yes           These 4 commands is a draft for how user control the
        input_file            string      yes           project run, I think we need to discuss about this in
        output_type           string      yes           team meeting.
        output_file           string      yes

        test_options          string      yes           In auto_test_function, I find that config is necessary for
                                                        user to test project. Score, judging script can make user
                                                        to config flexible test.
      2. The instrument_list is low limited, but user need to tell use the path of their input and output file.
         User can use command args or redirect to input or output, we only need to prepare input file in user gived
         path and read output file from user given path.
=end

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
    # todo: currently, we load test point from db, transfer them into txt
    # todo: in the future, we will offer the user a boolean var `use_text_file`
    # todo: if true, generate *.txt. Now we regarded it as true
    use_text_file = params[:use_text_file]
    if use_text_file.nil?
      # currently, default is `true`
      use_text_file = true
    end

    # check if there is a directory for this project, if not, create it
    project_dir_initializer(project_id)

    # generate data
    auto_test_point_root = "#{AUTO_TEST_PROJECT_ROOT}/#{project_id}/test_data"
    student_projects_root = "#{AUTO_TEST_PROJECT_ROOT}/#{project_id}/student_projects"
    if use_text_file
      auto_test_file_generator(project_id, auto_test_point_root)
    end

    # use git clone to get project
    git_clone_projects(project_id, git_repo_list)

    # then, we start to test
    # let user assume that he/she is at the project dir to run bash command for compile and run project

    c_lang_compiler = ''
    execute_instruction = ''
    main_name = 'main.c'
    output_name = 'output'

    if /darwin/i =~ RUBY_PLATFORM
      # BSD UNIX -> darwin -> macOS
      # in macOS, use clang in default
      c_lang_compiler = 'clang'
      execute_instruction = './a.out'
    elsif /linux/i =~ RUBY_PLATFORM
      # GNU Linux
      # in Linux, use gcc in default
      c_lang_compiler = 'gcc'
      execute_instruction = './a.out'
    else
      c_lang_compiler = 'gcc'
      # todo: in Linux & macOS, we use `./a.out` to run, check how it runs on Windows
      execute_instruction = './a.out'
    end
    instrument_list = ["#{c_lang_compiler} #{main_name}", "#{execute_instruction} > #{output_name}"]
    # instrument_list = ["#{c_lang_compiler} {main_name}"]

    result = exec_auto_test project_id.to_s, main_name, output_name, instrument_list


  end

  def get_auto_test_results

  end

end
