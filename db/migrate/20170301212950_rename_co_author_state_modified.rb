class RenameCoAuthorStateModified < ActiveRecord::Migration
  def change
    rename_column :authors, :co_author_state_modified, :co_author_state_modified_at
    rename_column :group_authors, :co_author_state_modified, :co_author_state_modified_at
  end
end
