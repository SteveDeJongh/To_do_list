require "pg"
# require 'pry'

class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "todos")
          end
    @logger = logger
  end

  def disconnect
    @db.close
  end

  def query(statement, *params)
    @logger.info("#{statement}: #{params}")
    @db.exec_params(statement, params)
  end

  def find_list(id)
    sql = <<~SQL
      SELECT lists.*, 
        COUNT(todos.id) AS todos_count,
        COUNT(NULLIF(todos.completed, true)) AS todos_remaining_count
        FROM lists 
        LEFT OUTER JOIN todos ON lists.id = todos.list_id 
        WHERE lists.id = $1
        GROUP BY lists.id
        ORDER BY lists.name;
    SQL
    result = query(sql, id)

    tuple_to_list_hash(result.first)
  end

  def all_lists
    sql = <<~SQL
      SELECT lists.*, 
        COUNT(todos.id) AS todos_count,
        COUNT(NULLIF(todos.completed, true)) AS todos_remaining_count
        FROM lists 
        LEFT OUTER JOIN todos ON lists.id = todos.list_id 
        GROUP BY lists.id
        ORDER BY lists.name;
    SQL

    result = query(sql)

    result.map do |tuple|
      tuple_to_list_hash(tuple)
    end
  end

  def create_new_list(list_name)
    sql = "INSERT INTO lists (name) VALUES ($1)"
    query(sql, list_name)
  end

  def delete_list(id)
    query("DELETE FROM todos WHERE list_id = $1", id)
    # required to delete referencing todos due to foreight key constraint.
    # If we added "ON DELETE CASCADE" clause this would not be required.
    query("DELETE FROM lists WHERE id = $1", id)
  end

  def update_list_name(id, new_name)
    sql = "UPDATE lists SET name = $2 WHERE id = $1"
    query(sql, id, new_name)
  end

  def create_new_todo(list_id, todo_name)
    sql = "INSERT INTO todos (name, list_id) VALUES ($1, $2)"
    query(sql, todo_name, list_id)
  end

  def delete_todo_from_list(list_id, todo_id)
    sql = "DELETE FROM todos WHERE id = $1 AND list_id = $2"
    query(sql, todo_id, list_id)
    # While not required to use both todo_id and list_id to delete a todo, it's a good idea
    # to be as specific as possible when performing destructive operations.
  end

  def update_todo_status(list_id, todo_id, new_status)
    sql = "UPDATE todos SET completed = $1 WHERE id = $2 AND list_id = $3"
    query(sql, new_status, todo_id, list_id)
  end

  def mark_all_todos_as_completed(list_id)
    sql = "UPDATE todos SET completed = true WHERE list_id = $1"
    query(sql, list_id)
  end

  def find_todos_for_list(list_id)
    todo_sql = "SELECT * FROM todos WHERE list_id = $1"
    todos_result = query(todo_sql, list_id)

    todos_result.map do |todo_tuple|
      { id: todo_tuple["id"].to_i,
        name: todo_tuple["name"],
        completed: todo_tuple["completed"] == "t" }
    end
  end

  private

  def tuple_to_list_hash(tuple)
    { id: tuple["id"].to_i,
      name: tuple["name"],
      todos_count: tuple["todos_count"].to_i,
      todos_remaining_count: tuple["todos_remaining_count"].to_i }
  end
end
