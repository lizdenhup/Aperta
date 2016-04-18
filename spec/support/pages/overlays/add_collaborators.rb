class AddCollaboratorsOverlay < PageFragment
  text_assertions :collaborator, ".collaborator .name"

  def add_collaborators(*users)
    users.map(&:full_name).each do |name|
      select2 name, css: '.collaborator-select', search: true
    end
  end

  def has_collaborators?(*collaborators)
    collaborators.all? do |collaborator|
      has_collaborator? collaborator.full_name
    end
  end

  def has_no_collaborators?
    has_no_css?(".collaborator")
  end

  def remove_collaborators(*collaborators)
    collaborators.map(&:email).each do |email|
      node = first('.collaborator .email', text: email)
      node.hover
      node.first('.delete-button').click
    end
  end

  def save
    find('.button-primary', text: 'SAVE').click
    wait_for_ajax
  end
end
