module AutoTestHelper
  AUTO_TEST_PROJECT_ROOT = 'auto_test_data'
  TEST_DATA_DIR_NAME = 'test_data'
  STUDENT_PROJECTS_DIR_NAME = 'student_projects'
  STUDENT_OUTPUT_DIR_NAME = 'student_output'

  def system_initializer
    # this should be called when you add this auto_test_system to the platform, see routes.rb
    if Dir.children('./').index(AUTO_TEST_PROJECT_ROOT)
      puts("[I] Dir #{AUTO_TEST_PROJECT_ROOT} already exists")
    else
      # `mkdir auto_test_data`
      # don't use shell instructions, use Ruby API
      puts("[I] Creating #{AUTO_TEST_PROJECT_ROOT}")
      Dir::mkdir(AUTO_TEST_PROJECT_ROOT, mode = 0777)
    end
  end

  def project_dir_initializer(project_id)
    # first init the system root dir
    system_initializer
    # then check project dir
    if Dir.children('./' + AUTO_TEST_PROJECT_ROOT).index(project_id.to_s)
      puts("[I] Project dir already exists")
    else
      puts("[I] Creating project dir #{project_id}")
      Dir::mkdir(AUTO_TEST_PROJECT_ROOT + '/' + project_id.to_s, mode = 0777)
      Dir::mkdir(AUTO_TEST_PROJECT_ROOT + '/' + project_id.to_s + "/#{TEST_DATA_DIR_NAME}", mode = 0777)
      Dir::mkdir(AUTO_TEST_PROJECT_ROOT + '/' + project_id.to_s + "/#{STUDENT_PROJECTS_DIR_NAME}", mode = 0777)
      Dir::mkdir(AUTO_TEST_PROJECT_ROOT + '/' + project_id.to_s + "/#{STUDENT_OUTPUT_DIR_NAME}", mode = 0777)
    end
  end

  def auto_test_file_generator(project_id, auto_test_point_root)
    puts("[I] Change working directory to #{auto_test_point_root}")
    Dir::chdir("#{auto_test_point_root}")

    # First, clean the directory
    Dir::children('./').each do |item|
      puts("[I] cleaning #{item}")
      `rm -r #{item}`
    end

    project_auto_test_point = AutoTestPoint.where(:project_id => project_id)
    project_auto_test_point.each_with_index do |item, cnt|
      atp_in_file = File.new("input_#{cnt}.txt", 'w')
      atp_out_file = File.new("output_#{cnt}.txt", 'w')
      atp_in_file.write(item.input)
      atp_out_file.write(item.expected_output)
      atp_in_file.close
      atp_out_file.close
    end
    puts("[I] Working path reset to root directory")
    Dir::chdir('../../../')
  end

  def git_clone_projects(project_id, git_repo_list)
    # git_ssh_addr format like: git@gitlab_server_ip:group_name/sub_group_name/project_name.git
    # remember to add id_rsa.pub into the SSH key rings of GitLab user 'root'
    # ATTENTION: project_id is public repo project id
    puts("[I] Change working directory to #{AUTO_TEST_PROJECT_ROOT}/#{project_id.to_s}/#{STUDENT_PROJECTS_DIR_NAME}")
    Dir::chdir("#{AUTO_TEST_PROJECT_ROOT}/#{project_id.to_s}/#{STUDENT_PROJECTS_DIR_NAME}")

    # First, clean the directory
    Dir::children('./').each do |item|
      puts("[I] cleaning #{item}")
      system "rm -r #{item}"
    end

    git_repo_list.each do |item|
      puts("[I] Cloning #{item}")
      `git clone #{item}`
    end
    # go back to root dir
    puts("[I] Working path reset to root directory")
    Dir::chdir('../../../')
  end

  def exec_auto_test(project_id, main_name, output_name, instrument_list)
    puts("[I] Change working directory to #{AUTO_TEST_PROJECT_ROOT}/#{project_id}")
    Dir::chdir("#{AUTO_TEST_PROJECT_ROOT}/#{project_id}")

    student_project_name_list = []
    test_cases = get_auto_test_cases

    Dir.children("#{STUDENT_PROJECTS_DIR_NAME}/").each do |item|
      student_project_name_list.append("#{item}")
    end

    student_project_name_list.each do |item|
      test_case.each do |num, files|
        # prepare input file to the porject dir.
        puts "[I] begin copying input file to #{STUDENT_PROJECTS_DIR_NAME}/#{item} dir."
        system "cp #{files["input"]} #{STUDENT_PROJECTS_DIR_NAME}/#{item}/"

        # run user`s instrument list for one student project.
        compile_and_run_single_project "#{STUDENT_PROJECTS_DIR_NAME}/#{item}", instrument_list

        # copy output file to STUDENT_OUTPUT_FIR_NAME for testing.
        # there could be several output file for many cases in #{STUDENT_OUTPUT_DIR_NAME}/#{item} dir.
        puts "[I] begin copying output file to STUDENT_OUTPUT_DIR_NAME for project #{item}"
        if !Dir::exist? "#{STUDENT_OUTPUT_DIR_NAME}/#{item}"
          Dir::mkdir "#{STUDENT_OUTPUT_DIR_NAME}/#{item}"
        end
        system "cp #{STUDENT_PROJECTS_DIR_NAME}/#{item}/#{output_name} #{STUDENT_OUTPUT_DIR_NAME}/#{item}/#{output_name}_#{num}"
      end
    end

    result = auto_test_result_compare test_cases, student_project_name_list, output_name

    puts("[I] Working path reset to root directory")
    Dir::chdir('../../')
    
    return result
  end

  # This function must be called in the exec_auto_test funtion to keep the correct state of directory.
  def get_auto_test_cases
    test_cases = {}

    Dir.children("#{TEST_DATA_DIR_NAME}/").each do |item|
      type = item.split('_')[0]
      num = item.split('_')[1].split('.')[0].to_i
      if test_case[num].nil?
        test_case[num] = {}
      end
      test_case[num][type] = "#{TEST_DATA_DIR_NAME}/#{item}"
    end
    return test_cases
  end

  # todo: intruduce docker to run user`s project. In this way, we can supply mutiply envs and isolate
  #        project running env and web server running env.
  # This function must be called in the exec_auto_test funtion to keep the correct state of directory.
  # This function is a solid function to run user`s instrument list.
  def compile_and_run_single_project(project_dir ,instrument_list)
    puts "[I] begin compiling and running project #{project_dir}"
      Dir::chdir(project_dir) do 
        instrument_list.each do |instrument|
          system instrument
        end
      end
  end

  # This function must be called in the exec_auto_test funtion to keep the correct state of directory.
  def auto_test_result_compare(test_cases, student_project_name_list, output_name)
    result = {}
    student_project_name_list.each do |item|
      if reset[item].nil?
        result[item] = {}
      end
      test_cases.each do |num, files|
        ouput_file = FILE::open "#{STUDENT_OUTPUT_DIR_NAME}/#{item}/#{output_name}_#{num}", "r"
        except_file = FILE::open files["except"], "r"
        result[item][num] = result_compare output, except_file
      end
    end
    return result
  end

  # todo: user could update compare file to define their special compare request.
  # todo: design a score mechanism for user to judge output more exactly.
  def result_compare(output_file, except_file)
    output = output_file.read.strip
    except = except_file.read.strip
    return output == except
  end

  # todo: then we need to figure out a method to compare
  # todo: def ... ...
end
