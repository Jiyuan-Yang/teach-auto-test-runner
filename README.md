# Auto Test Runner

本项目为BUAA SE Teaching Platform的一个组建，用于创建并进行自动化测试。

## 评测目录结构

默认建立在Runner的auto_test_data下，其内部结构为:
- project_id: 这里project指的是公共发布区的project_id
    - test_data: 用于存放txt格式的输入输出测试点
    - student_projects: 用于存放pull下来的学生仓库
    - student_output: 用于存放学生的输出

注意每次启动测试都应该对文件夹进行清空。

## API
```
post /create_auto_test_point
```
| 参数 | 类型 | 含义 |
| :------ | :------: | :------ |
| :project_id | integer | 评测点对应的项目ID，注意是公共发布区project的id |
| :input | text | 测试点输入 |
| :expected_output | text | 测试点期望输出 |

----

```
post /start_auto_test
```

| 参数             |  类型   | 含义                                                         |
| :--------------- | :-----: | :----------------------------------------------------------- |
| :project_id      | integer | 评测点对应的项目ID，注意是公共发布区project的id              |
| :git_repo_list   |  text   | 需要拉取的仓库地址，提供Http格式的地址，地址之间使用一个英文逗号分隔，整体为一个字符串 |
| :use_text_file   |  text   | 是否使用文本作为输入，若为True，则会在待测试的仓库中生成`input.txt`，若为False，直接使用标准输入 |
| :use_text_output |  text   | 是否使用文本作为输出，若为True，则测试的仓库中运行结束后应该生成`output.txt`，若为False，直接使用标准输出 |
| :compile_command | string  | 编译指令                                                     |
| :exec_command    | string  | 执行指令                                                     |

----

```
get /get_auto_test_results
```

| 参数        |  类型   | 含义                                            |
| :---------- | :-----: | :---------------------------------------------- |
| :project_id | integer | 评测点对应的项目ID，注意是公共发布区project的id |