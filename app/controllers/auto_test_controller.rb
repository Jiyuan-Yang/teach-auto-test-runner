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

  def get_auto_test_points
    @auto_test_points = AutoTestPoint.where(project_id: params[:project_id])
    points = Array.new
    @auto_test_points.each do |point|
      point.push({"input" => point["input"], "expected_output" => point["expected_output"]})
    end
    render json: points
    
  end

  def start_auto_test
    project_id = params[:project_id].to_i
    # use `,` to split
    # todo: here we use http to clone, consider to use SSH later
    # ATTENTION: the last element of project name should be user_id
    git_repo_list = params[:git_repo_list].split(',')
    # todo: currently, we load test point from db, transfer them into txt
    # todo: in the future, we will offer the user a boolean var `use_text_file`
    # todo: if true, generate *.txt. Now we regarded it as true
    use_text_file = params[:use_text_file]
    use_text_output = params[:use_text_output]
    if use_text_file.nil?
      # currently, default is `true`
      use_text_file = true
    end

    if use_text_output.nil?
      use_text_output = true
    end

    compile_command = params[:compile_command]
    exec_command = params[:exec_command]

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
    main_name = 'main.cpp'
    output_name = 'output'

    if /darwin/i =~ RUBY_PLATFORM
      # BSD UNIX -> darwin -> macOS
      # in macOS, use clang in default
      c_lang_compiler = 'clang++'
      execute_instruction = './a.out'
    elsif /linux/i =~ RUBY_PLATFORM
      # GNU Linux
      # in Linux, use gcc in default
      c_lang_compiler = 'g++'
      execute_instruction = './a.out'
    else
      c_lang_compiler = 'g++'
      # todo: in Linux & macOS, we use `./a.out` to run, check how it runs on Windows
      execute_instruction = './a.out'
    end

    if compile_command.nil?
      compile_command = "#{c_lang_compiler} #{main_name}"
    end

    if exec_command.nil?
      exec_command = "#{execute_instruction}"
    end

    if !use_text_output
      exec_command += " > #{output_name}.txt"
    end

    # instrument_list = ["#{c_lang_compiler} #{main_name}", "#{execute_instruction} > #{output_name}.txt"]
    instrument_list = [compile_command, exec_command]
    # instrument_list = ["#{c_lang_compiler} {main_name}"]

    result = exec_auto_test project_id.to_s, main_name, output_name, instrument_list

    puts('')
    puts('>>>>>>>>>>>> Collecting reuslts >>>>>>>>>>>>')
    puts(result)
    puts('>>>>>>>>>>>> Collecting reuslts >>>>>>>>>>>>')
    puts('')
    # import result
    result.keys.each do |key|
      user_id = key.split('_')[-1].to_i
      user_id2 = nil
      if params[:test_type] == 'pair'
        user_id2 = key.split('_')[-2].to_i
      end
      result[key].keys.each do |point_num_str|
        point_num = point_num_str.to_i
        score = 0
        if result[key][point_num_str] == true
          score = 1
        end
        @auto_test_result = AutoTestResult.find_by(
            :project_id => project_id, :user_id => user_id,
            :test_point_num => point_num
        )
        if params[:test_type] == 'pair'
          @auto_test_result2 = AutoTestResult.find_by(
              :project_id => project_id, :user_id => user_id2,
              :test_point_num => point_num
          )
        end
        if @auto_test_result.nil?
          @auto_test_result = AutoTestResult.new
          @auto_test_result.project_id = project_id
          @auto_test_result.user_id = user_id
          @auto_test_result.test_point_num = point_num
        end
        @auto_test_result.score = score
        @auto_test_result.save
        if params[:test_type] == 'pair'
          if @auto_test_result2.nil?
            @auto_test_result2 = AutoTestResult.new
            @auto_test_result2.project_id = project_id
            @auto_test_result2.user_id = user_id2
            @auto_test_result2.test_point_num = point_num
          end
          @auto_test_result2.score = score
          @auto_test_result2.save
        end
      end
    end
  end

  def get_auto_test_results
    # user should provide :project_id
    puts(">>>>>?????#{params}")
    project_id = params[:project_id].to_i
    puts(">>>>>>>><<<<<<<<")
    puts(project_id)
    all_result_in_project = AutoTestResult.where(:project_id => project_id)
    result_dict = {}
    all_user_id = []
    all_result_in_project.group(:user_id).each do |item|
      all_user_id.append(item.user_id)
    end
    all_user_id.each do |user_id|
      if result_dict[user_id].nil?
        result_dict[user_id] = {}
      end
      all_result_in_project.where(:user_id => user_id).each do |item|
        result_dict[user_id][item.test_point_num.to_i] = item.score.to_i
      end
    end
    puts('')
    puts('>>>>>>>>>>> Getting Reuslts >>>>>>>>>>>')
    puts(result_dict)
    puts('>>>>>>>>>>> Getting Reuslts >>>>>>>>>>>')
    puts('')
    render json: result_dict
  end
end
