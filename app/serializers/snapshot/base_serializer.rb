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

#
# A snapshot serializer is responsible for serializing a given object/model
# into an acceptable format for storing snapshots (see `Snapshot` class).
#
# By default serializing happens in the following order:
#
#   * nested questions - Only serialized if the given object/model responds to \
#     `nested_questions`. Ignored otherwise.
#   * properties - Override in subclass to provide an array of specific \
#     properties.
#
# === Serializing nested_questions
#
# When the object/model being serialized it will try to recursively serialize
# any of its `nested_questions` and their associated answers. The default method
# used for doing this is `snapshot_card_content`. In most cases you will not
# need to override this.
#
# When the object/model doesn't respond to `nested_questions` this will not
# not attempt to serialize nested questions. It will simply ignore them and
# move on.
#
# === Serializing properties
#
# The internal method used is `snapshot_properties`. It returns an empty
# array by default and should be overriden in subclasses to provide serialized
# properties as needed.
#
# There is a `snapshot_property(name, type, value)` helper method available to
# subclasses that can be used for formatting serialized properties.
#
# === Additional Notes
#
# This class was going to be named `Snapshot::Serializer`, but there was a name
# conflict and `Serializer` was being resolved to another class. Thus the name
# `BaseSerializer` was born.
#
class Snapshot::BaseSerializer
  attr_reader :model

  def initialize(model)
    @model = model
  end

  def as_json
    {
      name: model.class.name.demodulize.resourcerize,
      type: "properties",
      children: snapshot_children
    }
  end

  private

  def snapshot_children
    snapshot_card_content +
      [snapshot_property("id", "integer", model.id)] +
      snapshot_properties
  end

  # This method will need to change in the future to accomodate card content
  # without idents, but for now it's been changed around to keep the same
  # semantics as it had with nested questions
  def snapshot_card_content
    if model.try(:card_version).present?
      card_contents = model.card_version.content_root.children.order(:lft)

      card_contents.map do |card_content|
        Snapshot::CardContentSerializer.new(card_content, model).as_json
      end
    else
      []
    end
  end

  def snapshot_properties
    []
  end

  def snapshot_property(name, type, value)
    { name: name, type: type, value: value }
  end
end
