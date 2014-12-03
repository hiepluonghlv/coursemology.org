class LessonPlanEntriesController < ApplicationController
  load_and_authorize_resource :course
  load_and_authorize_resource :lesson_plan_entry, through: :course

  before_filter :load_general_course_data, :only => [:index, :new, :edit, :overview]

  def index
    @milestones = get_milestones_for_course(@course)
  end

  def new
      session[:ivle_token] = "E6E8F6C8B6732A2EFD8487B1ABED6456077EC2D710A350CB87B1FF90684182D00F56BA51A1D4D07A6A80699ED61EA20F90D5A938C8DBA85CE67B04D74F0191C26DDD34C6C8D1C6D64D28F95191BCF9951EDA6927A2C3459F38C7ACEB3E18C403B028FC88A4D0C5215E02C42CEDBAF282ACDA7ACCD24D13978E14C8FE6C5528566E1C0D4075529C76E6CF578C7C369ABB03CF00967661062F82B6DBF69D70370C07208E9F2D0108D9445501FD2F1F55F282AB93E372AA2FF4295F5D33AE9F9A984AFB6A20F3529AB76FD8E975E54ACD23"
    if !session[:ivle_token].nil?
      @ivle_token = session[:ivle_token]
    end

    @tags_list = {:origin => @lesson_plan_entry.topicconcepts.concepts.select(:name).map { |e| e.name }, :all => @course.topicconcepts.concepts.select(:name).map { |e| e.name }}

    @start_at = params[:start_at] || ""
    @end_at = params[:end_at] || ""

    @start_at = (DateTime.strptime(@start_at, '%d-%m-%Y') unless @start_at.empty?)
    @end_at = (DateTime.strptime(@end_at, '%d-%m-%Y') unless @end_at.empty?)
  end

  def create
    @lesson_plan_entry.creator = current_user
    @lesson_plan_entry.resources = if params[:resources] then
                                     build_resources(params[:resources])
                                   else
                                     []
                                   end

    #add tags
    if (!params["new_tags"].nil? && !params["original_tags"].nil?)
      if(params["new_tags"] != params["original_tags"])
        update_tag(JSON.parse(params["original_tags"]),JSON.parse(params["new_tags"]), nil)
      end
    end

    respond_to do |format|
      if @lesson_plan_entry.save then
        path = course_lesson_plan_path(@course) + "#entry-" + @lesson_plan_entry.id.to_s
        format.html { redirect_to path,
                      notice: "The lesson plan entry #{@lesson_plan_entry.title} has been created." }
      else
        format.html { render action: "new" }
      end
    end
  end

  def edit
    @tags_list = {:origin => @lesson_plan_entry.topicconcepts.concepts.select(:name).map { |e| e.name }, :all => @course.topicconcepts.concepts.select(:name).map { |e| e.name }}

  end

  def update
    @lesson_plan_entry.resources = if params[:resources] then
                                     build_resources(params[:resources])
                                   else
                                     []
                                   end

    #add tags
    if (!params["new_tags"].nil? && !params["original_tags"].nil?)
      if(params["new_tags"] != params["original_tags"])
        update_tag(JSON.parse(params["original_tags"]),JSON.parse(params["new_tags"]), nil)
      end
    end

    respond_to do |format|
      if @lesson_plan_entry.update_attributes(params[:lesson_plan_entry]) && @lesson_plan_entry.save then
        path = course_lesson_plan_path(@course) + "#entry-" + @lesson_plan_entry.id.to_s
        format.html { redirect_to path,
                      notice: "The lesson plan entry #{@lesson_plan_entry.title} has been updated." }
      else
        format.html { render action: "index" }
      end
    end
  end

  def destroy
    @lesson_plan_entry.destroy
    respond_to do |format|
      format.html { redirect_to :back,
                    notice: "The lesson plan entry #{@lesson_plan_entry.title} has been removed." }
    end
  end

  def overview
    @milestones = get_milestones_for_course(@course)
    render "/lesson_plan/overview"
  end

private
  def render(*args)
    options = args.extract_options!
    options[:template] = "/lesson_plan/#{options[:action] || params[:action]}"
    super(*(args << options))
  end

  # Builds the resource array to be assigned to a model from form parameters
  def build_resources(param)
    resources = []
    param.each { |r|
      obj_parts = r.split(',')
      res = LessonPlanResource.new
      res.obj_id = obj_parts[0]
      res.obj_type = obj_parts[1]
      resources.push(res)
    }

    resources
  end

  def get_milestones_for_course(course)
    milestones = course.lesson_plan_milestones.accessible_by(current_ability).order("start_at")


    other_entries_milestone = create_other_items_milestone(milestones)
    prior_entries_milestone = create_prior_items_milestone(milestones)

    milestones <<= other_entries_milestone
    if prior_entries_milestone
      milestones.insert(0, prior_entries_milestone)
    end

    milestones
  end

  def entries_between_date_range(start_date, end_date)
    if can? :manage, Assessment::Mission
      virtual_entries = @course.lesson_plan_virtual_entries(start_date, end_date)
    else
      virtual_entries = @course.lesson_plan_virtual_entries(start_date, end_date).select { |entry| entry.is_published }
    end

    after_start = if start_date then "AND start_at > :start_date " else "" end
    before_end = if end_date then "AND end_at < :end_date" else "" end

    actual_entries = @course.lesson_plan_entries.where("TRUE " + after_start + before_end,
      :start_date => start_date, :end_date => end_date)

    entries_in_range = virtual_entries + actual_entries
    entries_in_range.sort_by { |e| e.start_at }
  end

  def create_other_items_milestone(all_milestones)
    last_milestone = if all_milestones.length > 0 then
      all_milestones[all_milestones.length - 1]
    else 
      nil
    end

    other_entries = if last_milestone and last_milestone.end_at then
      entries_between_date_range(last_milestone.end_at.advance(:days =>1), nil)
    elsif last_milestone
      []
    else
      entries_between_date_range(nil, nil)
    end

    other_entries_milestone = LessonPlanMilestone.create_virtual("Other Items", other_entries)
    other_entries_milestone.previous_milestone = last_milestone
    other_entries_milestone
  end

  def create_prior_items_milestone(all_milestones)
    first_milestone = if all_milestones.length > 0 then
      all_milestones[0]
    else
      nil
    end

    if first_milestone
      entries_before_first = entries_between_date_range(nil, first_milestone.start_at)
      prior_entries_milestone = LessonPlanMilestone.create_virtual("Prior Items", entries_before_first)
      prior_entries_milestone.next_milestone = first_milestone
      prior_entries_milestone
    end
  end

  def update_tag(original_tags, new_tags, group)
    new_tags.each do |obj|
      if(!original_tags.include? obj)
        tag_element = @course.topicconcepts.where(:name => obj).first
        if(!tag_element.nil?)
          taggable = @lesson_plan_entry.taggable_tags.new
          taggable.tag = tag_element
          taggable.save
        end
      end
    end

    original_tags.each do |obj|
      if(!new_tags.include? obj)
        tag_element = @course.topicconcepts.where(:name => obj).first
        if(!tag_element.nil?)
          taggable = @lesson_plan_entry.taggable_tags.where(:tag_type => 'Topicconcept', :tag_id => tag_element.id).first
          if(!taggable.nil?)
            taggable.destroy
          end
        end
      end
    end
  end
end
