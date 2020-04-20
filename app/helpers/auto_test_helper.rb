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

  # todo: use this method to get users' compiling instruction (stage 1)
  def exec_auto_test(project_id, main_name, output_name, instrument_list)
    puts("[I] Change working directory to #{AUTO_TEST_PROJECT_ROOT}/#{project_id}")
    Dir::chdir("#{AUTO_TEST_PROJECT_ROOT}/#{project_id}")

    student_project_path_list = []

    Dir.children("#{STUDENT_PROJECTS_DIR_NAME}/").each do |item|
      student_project_path_list.append("#{STUDENT_PROJECTS_DIR_NAME}/#{item}")
    end

    instrument_list[0].sub('{main_name}', main_name)
    instrument_list[1].sub('{output_name}', output_name)
    student_project_path_list.each do |item|
      compile_and_run_single_project item, instrument_list
    end

    # there could be several output file for many cases in #{STUDENT_OUTPUT_DIR_NAME}/#{item} dir.
    student_project_path_list.each do |item|
      puts "[I] begin copying output file to STUDENT_OUTPUT_DIR_NAME for project #{item}"
      if !Dir::exist? "#{STUDENT_OUTPUT_DIR_NAME}/#{item}"
        Dir::mkdir "#{STUDENT_OUTPUT_DIR_NAME}/#{item}"
      end
      system "cp #{STUDENT_PROJECTS_DIR_NAME}/#{item}/#{output_name} #{STUDENT_OUTPUT_DIR_NAME}/#{item}/#{output_name}"
    end

    puts("[I] Working path reset to root directory")
    Dir::chdir('../../')
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

  # This function must be called in the exec_auto_test funtion to keep the correct state of directory.
  def compile_and_run_single_project(project_dir ,instrument_list)
    puts "[I] begin compiling and running project #{project_dir}"
      Dir::chdir(project_dir) do 
        instrument_list.each do |instrument|
          system instrument
        end
      end
  end

  # todo: use this method to get users' executing instruction (stage 2)
  # todo: we could save files into one place
  def auto_test_result_compare(test_cases)
  end

  # todo: then we need to figure out a method to compare
  # todo: def ... ...
end
