module Hierarchical
  extend ActiveSupport::Concern

  def load
    contents = recursive_load(id)
    contents = contents.group_by { |row| row['id'] }
    attrs = contents.each_with_object({}) { |(id, rows), hash| hash[id] = extract_attributes(rows) }
    validations = contents.each_with_object({}) { |(id, rows), hash| hash[id] = extract_validations(rows) }

    contents = merge_attributes(contents, attrs, validations)
    construct_hierarchy(contents)
  end

  private

  def recursive_load(id)
    result = self.class.connection.select_all(combined_sql(id))
    result.map do |row|
      row.each { |key, value| row[key] = result.column_types[key].type_cast_from_database(value) }
    end
  end

  def construct_hierarchy(contents)
    root = nil
    contents.keys.each do |id|
      row = contents[id]
      parent_id = row.delete('parent_id')
      if parent_id.nil?
        root = id
        next
      end
      parent = contents[parent_id]
      next unless parent
      (parent['children'] ||= []) << row
    end
    contents[root]
  end

  def merge_attributes(contents, attrs, validations)
    contents.each_with_object({}) do |(id, rows), hash|
      rows.first.try do |row|
        clean_attributes(row)
        id = row['id']
        hash[id] = row.merge('attributes' => attrs[id], 'validations' => validations[id])
      end
    end
  end

  def extract_attributes(rows)
    rows.each_with_object({}) do |row, hash|
      key = "#{row['value_type']}_value"
      hash[row['attribute']] = row[key]
    end
  end

  VALIDATION_KEYS = %w[validation_type validator error_message].freeze
  def extract_validations(rows)
    unique = rows.each_with_object({}) do |row, hash|
      values = VALIDATION_KEYS.map { |key| row[key] }.compact
      next if values.empty?
      hash[row['val_id']] = VALIDATION_KEYS.each_with_object({}) { |key, validation| validation[key] = row[key] }
    end

    unique.values
  end

  METADATA_KEYS = %w[val_id attribute path value_type].freeze
  def clean_attributes(row)
    METADATA_KEYS.each { |key| row.delete(key) }
    VALIDATION_KEYS.each { |key| row.delete(key) }
    Attributable::CONTENT_TYPES.each { |type| row.delete("#{type}_value") }
  end

  def combined_sql(id)
    <<-SQL
    with recursive all_contents as (
      select
        base.id, base.parent_id, array[base.id] AS path,
        base.content_type, base.ident,
        attr.name as attribute,
        attr.value_type, attr.string_value, attr.integer_value, attr.boolean_value, attr.json_value,
        vals.id as val_id,
        vals.validation_type, vals.validator, vals.error_message
      from
        card_contents base
        left outer join content_attributes attr on attr.card_content_id = base.id
        left outer join card_content_validations vals on vals.card_content_id = base.id
      where
        parent_id is NULL and card_version_id = #{id}

      UNION

      select
        cc.id, cc.parent_id, (base.path || cc.id) as path,
        cc.content_type, cc.ident,
        attr.name as attribute,
        attr.value_type, attr.string_value, attr.integer_value, attr.boolean_value, attr.json_value,
        vals.id as val_id,
        vals.validation_type, vals.validator, vals.error_message
      from
        card_contents cc
        inner join all_contents base on base.id = cc.parent_id
        left outer join content_attributes attr on attr.card_content_id = cc.id
        left outer join card_content_validations vals on vals.card_content_id = cc.id
      where
        card_version_id = #{id}
    )

    select * from all_contents order by path;
    SQL
  end
end
