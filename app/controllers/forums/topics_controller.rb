class Forums::TopicsController < ApplicationController
  load_and_authorize_resource :course
  before_filter :load_general_course_data, except: [:destroy]

  before_filter :load_forum
  load_and_authorize_resource :forum
  before_filter :load_topic
  load_and_authorize_resource :topic, class: ForumTopic

  def show
    respond_to do |format|
      format.html { render action: 'show' }
    end

    if curr_user_course.persisted? then
      topic_view = ForumTopicView.create
      topic_view.topic = @topic
      topic_view.user = curr_user_course
      topic_view.save

      curr_user_course.mark_as_seen(@topic)
      curr_user_course.mark_as_seen(@topic.posts)
    end
  end

  def new

  end

  def create
    if params[:topic_title].nil?
      authorize_topic_type!(params[:forum_topic][:topic_type].to_i)

      post = nil
      ForumTopic.transaction do
        post = ForumPost.new
        post.assign_attributes(params[:forum_topic][:posts])
        post.author = curr_user_course

        params[:forum_topic].delete(:posts)
        @topic.assign_attributes(params[:forum_topic])
        @topic.title = post.title
        @topic.author = curr_user_course
        @topic.forum = @forum

        @topic.save
        post.topic = @topic
        post.save

        # Create the activity feed record
        case @topic.topic_type
          when ForumTopic::TOPIC_TYPE_QUESTION
            Activity.asked_question(curr_user_course, @topic)
          else
            Activity.created_forum_topic(curr_user_course, @topic)
        end
      end

      respond_to do |format|
        format.html { redirect_to course_forum_topic_path(@course, @forum, @topic),
                                  notice: 'The topic was successfully created.' }
      end
    else
      if params["redirect_link"]
        @topic.forum = @course.forums.first
        @topic.author = curr_user_course
        @topic.title = params[:topic_type] + " " + params[:topic_title]
        @topic.discussable = LessonPlanEntry.find_by_id(params[:redirect_link].split('-')[1].to_i)
        @topic.save

        post = ForumPost.new
        post.assign_attributes(params[:forum_post])
        post.author = curr_user_course
        post.topic = @topic
        post.save

        respond_to do |format|
          format.html { redirect_to (course_lesson_plan_path(@course) + "?eid=#{params["redirect_link"]}" + "#post-#{post.id}") }
        end
      elsif params["assessment_redirect_link"]
        @topic.forum = @course.forums.first
        @topic.author = curr_user_course
        @topic.title = params[:topic_type] + " " + params[:topic_title]
        @topic.discussable = Assessment.find_by_id(params[:topic_id].to_i)
        @topic.save

        post = ForumPost.new
        post.assign_attributes(params[:forum_post])
        post.author = curr_user_course
        post.topic = @topic
        post.save

        respond_to do |format|

          format.html { redirect_to params["assessment_redirect_link"] + ((params["assessment_redirect_link"].to_s.include? "step") ? "&discuss=true" : "?discuss=true") }
        end
      end

    end

  end

  def edit

  end

  def update
    params[:forum_topic][:forum] = @course.forums.where(id: params[:forum_topic][:forum].to_i).first!
    authorize_topic_type!(params[:forum_topic][:topic_type].to_i)
    @topic.assign_attributes(params[:forum_topic])


    respond_to do |format|
      if @topic.save
        format.html { redirect_to course_forum_topic_path(@course, @topic.forum, @topic),
                                  notice: 'The topic was successfully updated.' }
      end
    end
  end

  def set_type
    authorize! :edit, @topic
    authorize_topic_type!(params[:type].to_i)

    @topic.topic_type = params[:type]
    respond_to do |format|
      if @topic.save then
        format.html { redirect_to course_forum_topic_path(@course, @forum, @topic),
                                  notice: 'The topic type was successfully updated.' }
        format.json { { status: 'OK' } }
      else
        format.html { redirect_to course_forum_topic_path(@course, @forum, @topic),
                                  flash: { error: 'The topic type could not be updated.' } }
        format.json { { status: 'Error' } }
      end
    end
  end

  def set_lock
    authorize! :edit, @topic
    @topic.locked = params[:lock]

    respond_to do |format|
      if @topic.save then
        format.html { redirect_to course_forum_topic_path(@course, @forum, @topic),
                                  notice: "The topic was was successfully #{params[:lock] ? 'locked' : 'unlocked'}." }
        format.json { { status: 'OK' } }
      else
        format.html { redirect_to course_forum_topic_path(@course, @forum, @topic),
                                  flash: { error: "The topic type could not be #{params[:lock] ? 'locked' : 'unlocked'}." } }
        format.json { { status: 'Error' } }
      end
    end
  end

  def set_hide
    authorize! :edit, @topic
    @topic.hidden = params[:hide]

    respond_to do |format|
      if @topic.save then
        format.html { redirect_to course_forum_topic_path(@course, @forum, @topic),
                                  notice: "The topic was was successfully #{params[:hide] ? 'hidden' : 'shown'}." }
        format.json { { status: 'OK' } }
      else
        format.html { redirect_to course_forum_topic_path(@course, @forum, @topic),
                                  flash: { error: "The topic type could not be #{params[:hide] ? 'hidden' : 'shown'}." } }
        format.json { { status: 'Error' } }
      end
    end
  end

  def destroy
    @topic.destroy

    respond_to do |format|
      format.html { redirect_to course_forum_path(@course, @forum),
                                notice: 'The topic was successfully deleted.'}
    end
  end

  def subscribe
    subscription = ForumTopicSubscription.create
    subscription.topic = @topic
    subscription.user = curr_user_course

    respond_to do |format|
      if subscription.save
        format.html { redirect_to course_forum_topic_path(@course, @forum, @topic),
                                  notice: 'You have subscribed to the topic.' }
      end
    end
  end

  def unsubscribe
    ForumTopicSubscription.delete_all(topic_id: @topic, user_id: curr_user_course)

    respond_to do |format|
      format.html { redirect_to course_forum_topic_path(@course, @forum, @topic),
                                notice: 'You have been unsubscribed from the topic.' }
    end
  end

private
  def load_forum
    @forum = ForumForum.find_using_slug(params[:forum_id])
    raise ActiveRecord::RecordNotFound unless @forum
  end

  def load_topic
    @topic = ForumTopic.find_using_slug(params[:id] || params[:topic_id])
    if %w(new create).include?(params[:action])
      @topic = ForumTopic.new
      # No implicit assignment of attributes to the @post property. We need to create the post first before
      # creating the topic.
    end

    raise ActiveRecord::RecordNotFound unless @topic
  end

  def authorize_topic_type!(type)
    case type
      when ForumTopic::TOPIC_TYPE_STICKY
        authorize!(:set_sticky, @topic)
      when ForumTopic::TOPIC_TYPE_ANNOUNCEMENT
        authorize!(:set_announcement, @topic)
    end
  end
end
