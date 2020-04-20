# Auto Test Runner

本项目为BUAA SE Teaching Platform的一个组建，用于创建并进行自动化测试。

## 评测目录结构

默认建立在Runner的auto_test_data下，其内部结构为：
- project_id: 这里project指的是公共发布区的project_id
    - test_data: 用于存放txt格式的输入输出测试点
    - student_projects: 用于存放pull下来的学生仓库

## API
```
post '/create_auto_test_point'
```
| 参数 | 类型 | 含义 |
| :------ | :------: | :------ |
| :project_id | integer | 评测点对应的项目ID，注意是公共发布区project的id |
| :input | text | 测试点输入 |
| :expected_output | text | 测试点期望输出 |


----