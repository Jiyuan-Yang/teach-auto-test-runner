module AutoTestHelper
  AUTO_TEST_PROJECT_ROOT = 'auto_test_data'

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
      Dir::mkdir(AUTO_TEST_PROJECT_ROOT + '/' + project_id.to_s + '/test_data', mode = 0777)
      Dir::mkdir(AUTO_TEST_PROJECT_ROOT + '/' + project_id.to_s + '/student_projects', mode = 0777)
    end
  end

  def git_pull_projects(project_id, git_ssh_addr_list)
    # git_ssh_addr format like: git@gitlab_server_ip:group_name/sub_group_name/project_name.git
    # remember to add id_rsa.pub into the SSH key rings of GitLab user 'root'
    # ATTENTION: project_id is public repo project id
    puts("[I] Change working directory to #{AUTO_TEST_PROJECT_ROOT}/#{project_id.to_s}/student_projects")
    Dir::chdir("#{AUTO_TEST_PROJECT_ROOT}/#{project_id.to_s}/student_projects")
    git_ssh_addr_list.each do |item|
      puts("[I] Cloning #{item}")
      `git clone #{item}`
    end
    # go back to root dir
    Dir::chdir('../../../')
  end
end
