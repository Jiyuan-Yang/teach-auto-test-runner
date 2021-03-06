require 'open4'

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
    puts("[Debug] #{project_auto_test_point}")
    puts("[Debug] #{project_id}")
    project_auto_test_point.each_with_index do |item, cnt|
      atp_in_file = File.new("input_#{cnt}.txt", 'w')
      atp_out_file = File.new("output_#{cnt}.txt", 'w')
      puts("[I] Creating test point, id: #{item.id}, project_id: #{item.project_id} input: #{item.input}, output: #{item.expected_output}")
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
      puts("[I] cleaning #{item} -rf")
      system "rm -rf #{item}"
    end

    git_repo_list.each do |item|
      puts("[I] Cloning #{item}")
      `git clone #{item}`
    end
    # go back to root dir
    puts("[I] Working path reset to root directory")
    Dir::chdir('../../../')
  end

  def exec_auto_test(project_id, main_name, output_name, instruments, limitation)
    puts("[I] Change working directory to #{AUTO_TEST_PROJECT_ROOT}/#{project_id}")
    Dir::chdir("#{AUTO_TEST_PROJECT_ROOT}/#{project_id}")

    student_project_name_list = []
    test_cases = get_auto_test_cases

    Dir.children("#{STUDENT_PROJECTS_DIR_NAME}/").each do |item|
      student_project_name_list.append("#{item}")
    end

    total_result = {running_status: {}, results: {}}
    student_project_name_list.each do |item|
      test_cases.each do |num, files|
        # prepare input file to the project dir.
        puts "[I] begin copying input file to #{STUDENT_PROJECTS_DIR_NAME}/#{item} dir."
        system "cp #{files["input"]} #{STUDENT_PROJECTS_DIR_NAME}/#{item}/input.txt"

        # run user`s instrument list for one student project.
        total_result[:running_status][item] =  compile_and_run_single_project "#{STUDENT_PROJECTS_DIR_NAME}/#{item}", instruments, limitation

        # copy output file to STUDENT_OUTPUT_FIR_NAME for testing.
        # there could be several output file for many cases in #{STUDENT_OUTPUT_DIR_NAME}/#{item} dir.
        puts "[I] begin copying output file to #{STUDENT_OUTPUT_DIR_NAME} for project #{item}"
        if !Dir::exist? "#{STUDENT_OUTPUT_DIR_NAME}/#{item}"
          Dir::mkdir "#{STUDENT_OUTPUT_DIR_NAME}/#{item}"
        end

        # judge if there is an output file
        if Dir.children("#{STUDENT_PROJECTS_DIR_NAME}/#{item}/").index('output.txt').nil?
          File.new("#{STUDENT_PROJECTS_DIR_NAME}/#{item}/#{output_name}.txt", "w")
        end

        system "cp #{STUDENT_PROJECTS_DIR_NAME}/#{item}/#{output_name}.txt #{STUDENT_OUTPUT_DIR_NAME}/#{item}/#{output_name}_#{num}.txt"
      end
    end

    total_result[:results] = auto_test_result_compare test_cases, student_project_name_list, output_name

    puts("[I] Working path reset to root directory")
    Dir::chdir('../../')
    
    total_result
  end

  # This function must be called in the exec_auto_test function to keep the correct state of directory.
  def get_auto_test_cases
    test_cases = {}

    Dir.children("#{TEST_DATA_DIR_NAME}/").each do |item|
      type = item.split('_')[0]
      num = item.split('_')[1].split('.')[0].to_i
      if test_cases[num].nil?
        test_cases[num] = {}
      end
      test_cases[num][type] = "#{TEST_DATA_DIR_NAME}/#{item}"
    end
    test_cases
  end

  # todo: introduce docker to run user`s project. In this way, we can supply multiply envs and isolate
  #        project running env and web server running env.
  # This function must be called in the exec_auto_test function to keep the correct state of directory.
  # This function is a solid function to run user`s instrument list.
  def compile_and_run_single_project(project_dir, instruments, limitation)
    puts "[I] begin compiling and running project #{project_dir}"
    Dir::chdir(project_dir) do
      now_period = ''
      begin
        instruments.each do |period, instrument_list|
          now_period = period
          if period == 'compile'
            instrument_list.each do |instrument|
              status = open4.spawn instrument
            end
          elsif period == 'exec'
            instrument_list.each do |instrument|
              status = open4.spawn instrument, :timeout => limitation[:time]
            end
          end
        end
      rescue SpawnError
        return {status: 'error', period: now_period, exitstatus: SpawnError.exitstatus}
      end
    end
    {status: 'ok'}
  end

  # This function must be called in the exec_auto_test funtion to keep the correct state of directory.
  def auto_test_result_compare(test_cases, student_project_name_list, output_name)
    result = {}
    student_project_name_list.each do |item|
      if result[item].nil?
        result[item] = {}
      end
      test_cases.each do |num, files|
        # puts("[Debug] :::::::::: #{Dir.pwd}")
        # puts("#{STUDENT_OUTPUT_DIR_NAME}/#{item}/#{output_name}_#{num}.txt")
        # puts(files["output"])
        # puts('>>>>>')
        # puts("#{Dir.pwd}/#{STUDENT_OUTPUT_DIR_NAME}/#{item}/#{output_name}_#{num}.txt")
        output_file = File.open("#{STUDENT_OUTPUT_DIR_NAME}/#{item}/#{output_name}_#{num}.txt", "r")
        # expected_file = FILE::open files["expected"], "r"
        expected_file = File.open("#{files["output"]}", "r")
        result[item][num] = result_compare output_file, expected_file

      end
    end
    result
  end

  # todo: user could update compare file to define their special compare request.
  # todo: design a score mechanism for user to judge output more exactly.
  def result_compare(output_file, expected_file)
    output = output_file.read.strip
    expected = expected_file.read.strip
    output == expected
  end
end
