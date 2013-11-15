Forem::ForumsController.class_eval do
  load_and_authorize_resource :forum, :except => [:mark_read, :next_unread]
  append_before_filter :shim

  def mark_read
    unread = Forem::Post.unread_by(current_user).select { |p| p.topic.forum.id == @forum.id }
    Forem::Post.mark_as_read! unread, :for => current_user
    redirect_to main_app.course_forum_path(@course, @forum)
  end

  def next_unread
    unread = Forem::Post.unread_by(current_user).select { |p| p.topic.forum.id == @forum.id }
    if unread.count > 0
      redirect_to main_app.course_forum_topic_url(@course, @forum, unread.first.topic)
    else
      redirect_to main_app.course_forum_path(@course, @forum)
    end
  end

  private

  def shim
    unless @forum
      @forum = Forem::Forum.find(params[:forum_id])
    end
    @course = Course.find(@forum.category.id)
    @current_ability = CourseAbility.new(current_user, curr_user_course)
    load_general_course_data
    ensure_logged_in
  end
end