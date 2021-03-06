# Copyright (c) 2018 Public Library of Science

# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

# Moves all data in question_attachments to the attachments table
# and removes the question_attachments table.
class MoveQuestionAttachmentDataToAttachment < ActiveRecord::Migration
  def up
    question_attachment_count = count 'question_attachments'
    starting_attachment_count = count 'attachments'

    execute <<-SQL
      INSERT INTO attachments
            (old_id, owner_id,                  owner_type,             file,       title, caption, status, token, type,                 s3_dir, created_at, updated_at)
      SELECT id,     nested_question_answer_id, 'NestedQuestionAnswer', attachment, title, caption, status, token, 'QuestionAttachment', s3_dir, created_at, updated_at
      FROM question_attachments
    SQL

    execute <<-SQL
      UPDATE attachments
      SET paper_id=nested_question_answers.paper_id
      FROM nested_question_answers
      WHERE nested_question_answers.id=attachments.owner_id AND attachments.owner_type='NestedQuestionAnswer'
    SQL

    ending_attachment_count = count 'attachments'
    delta = ending_attachment_count - starting_attachment_count - question_attachment_count
    unless delta == 0
      fail "Expected to move all the question_attachments to the attachments table, but was off by #{delta}"
    end
    drop_table :question_attachments
  end

  def down
    create_table "question_attachments" do |t|
      t.integer  "nested_question_answer_id"
      t.string   "attachment"
      t.string   "title"
      t.string   "status"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "token"
      t.string   "caption"
      t.text     "s3_dir"
    end

    execute <<-SQL
      INSERT INTO question_attachments
            (id,     nested_question_answer_id, attachment, title, status, token, caption, s3_dir, created_at, updated_at)
      SELECT old_id, owner_id,                  file,       title, status, token, caption, s3_dir, created_at, updated_at
      FROM attachments
      WHERE type='QuestionAttachment'
    SQL

    add_index "question_attachments", ["nested_question_answer_id"], name: "index_question_attachments_on_nested_question_answer_id", using: :btree
    add_index "question_attachments", ["token"], name: "index_question_attachments_on_token", unique: true, using: :btree

    execute <<-SQL
      DELETE FROM attachments
      WHERE type='QuestionAttachment'
    SQL
  end

  private

  def count(table_name)
    column_name = "#{table_name}_count"
    sql_result = execute("SELECT COUNT(*) as #{column_name} FROM #{table_name}")
    sql_result.field_values(column_name).first.to_i
  end
end
