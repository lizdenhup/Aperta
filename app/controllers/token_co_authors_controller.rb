# Serves as the method for non-users to conform co-authorship without signing in.
class TokenCoAuthorsController < ApplicationController
  def show
    if author.co_author_confirmed?
      redirect_to thank_you_token_co_author_path(token)
    end

    assign_template_vars
  end

  def confirm
    if author.co_author_confirmed?
      return redirect_to thank_you_token_co_author_path(token)
    end

    author.co_author_confirmed!
    Activity.co_author_confirmed!(author, user: current_user)
    redirect_to thank_you_token_co_author_path(token)
  end

  def thank_you
    redirect_to show_token_co_author_path(token) unless author.co_author_confirmed?
    assign_template_vars
  end

  private

  def assign_template_vars
    @author = author
    @authors = authors
    @paper = author.paper
    @journal_logo_url = @paper.journal.logo_url
  end

  def token
    params[:token] || params[:invitation][:token]
  end

  def authors
    @authors ||= author
                 .paper
                 .author_list_items
                 .map(&:author)
  end

  def author
    @author ||= Author.find_by_token!(token)
  end
end
