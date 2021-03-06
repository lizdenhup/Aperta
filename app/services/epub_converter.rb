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

# Autoloader is not thread-safe in 4.x; it is fixed for Rails 5.
# Explicitly require any dependencies outside of app/. See a9a6cc for more info.
require_dependency 'tahi_epub'

class EpubConverter
  attr_reader :paper, :downloader

  include DownloadablePaper

  # == Constructor Arguments
  # * paper: The Paper in question
  # * downloader: The user who appears in the PDF conversion's footer
  def initialize(paper, downloader = nil)
    @paper = paper
    @downloader = downloader # a user
  end

  def epub_stream
    @epub_stream ||= builder.generate_epub_stream
  end

  def title
    CGI.escape_html(paper.short_title.to_s)
  end

  # Yeah these methods that start with _ should be private
  # Unfortunately the way the GEPUB library works uses
  # instance eval so we need them to be public until
  # such time as we are angry enough to build it another way.
  #
  def _embed_source(workdir)
    FileUtils.mkdir_p _source_dir(workdir)
    File.open(_path_to_source(workdir), 'wb') do |f|
      f.write manuscript_source_contents
    end
  end

  def _source_dir(workdir)
    "#{workdir}/input"
  end

  def _path_to_source(workdir)
    "#{_source_dir(workdir)}/#{_manuscript_source_path.basename}"
  end

  def _manuscript_source_path
    @manuscript_source_path ||= Pathname.new(manuscript_source.path)
  end

  private

  def write_to_file(dir, content, filename)
    File.open(File.join(dir, filename), 'w+') do |file|
      file.write content
      file.flush
      file.path
    end
  end

  def builder
    Dir.mktmpdir do |dir|
      content_file_path = write_to_file dir, '<html></html>', 'content.html'
      generate_epub_builder content_file_path
    end
  end

  def generate_epub_builder(temp_paper_path)
    workdir = File.dirname temp_paper_path
    this = self

    GEPUB::Builder.new do
      language 'en'
      unique_identifier 'http://tahi.org/hello-world', 'B, falseookID', 'URL'
      title this.paper.display_title
      creator this.paper.creator.full_name
      date Date.today.to_s
      if this.paper.latest_version.present?
        this._embed_source(workdir)
        # keep same file extension as original file
        ext = this._manuscript_source_path.extname.downcase
        optional_file "input/source#{ext}" => this._path_to_source(workdir)
      end
      resources(workdir: workdir) do
        ordered do
          file "./#{File.basename temp_paper_path}"
          heading 'Main Content'
        end
      end
    end
  end

  def manuscript_source
    @manuscript_source ||= paper.file.to_file
  end

  def manuscript_source_contents
    @manuscript_source_contents ||= manuscript_source.read
  end
end
