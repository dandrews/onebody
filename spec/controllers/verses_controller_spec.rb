require_relative '../spec_helper'

describe VersesController do
  render_views

  before do
    allow_any_instance_of(Verse).to receive(:lookup) do |i|
      i.translation = 'WEB'
      i.text = 'test'
      i.update_sortables
    end
    @person, @other_person = FactoryGirl.create_list(:person, 2)
    2.times { @person.verses       << FactoryGirl.create(:verse, tag_list: 'foo bar') }
    2.times { @other_person.verses << FactoryGirl.create(:verse, tag_list: 'baz foo') }
    @verse = Verse.first
  end

  it "should show a paginated listing of all verses with a tag cloud" do
    get :index, nil, {logged_in_id: @person.id}
    expect(response).to be_success
    expect(assigns(:verses).length).to eq(4)
    expect(assigns(:tags).length).to eq(3)
  end

  it "should show one verse" do
    get :show, {id: @verse.id}, {logged_in_id: @person.id}
    expect(response).to be_success
    assert_select 'h1', Regexp.new(@verse.reference)
  end

  it "should tag a verse" do
    expect(@verse.tag_list.length).to eq(2)
    # add just 1
    get :update, {id: @verse.id, add_tags: 'dude'}, {logged_in_id: @person.id}
    expect(response).to redirect_to(verse_path(@verse))
    expect(@verse.reload.tag_list.length).to eq(3)
    # add 2 more
    get :update, {id: @verse.id, add_tags: 'two more'}, {logged_in_id: @person.id}
    expect(response).to redirect_to(verse_path(@verse))
    expect(@verse.reload.tag_list.length).to eq(5)
  end

  it "should remove a tag from a verse" do
    expect(@verse.tag_list.length).to eq(2)
    # remove 1
    get :update, {id: @verse.id, remove_tag: 'foo'}, {logged_in_id: @person.id}
    expect(response).to redirect_to(verse_path(@verse))
    expect(@verse.reload.tag_list.length).to eq(1)
  end

  it "should add a verse (to the user)" do
    @verse.people.delete @person
    expect(@person.verses.reload).to_not include(@verse)
    post :create, {id: @verse.id}, {logged_in_id: @person.id}
    expect(response).to redirect_to(verse_path(@verse))
    expect(@person.verses.reload).to include(@verse)
  end

  it "should remove a verse (from the user)" do
    @verse.people << @other_person
    expect(@verse.people.count).to eq(2)
    expect(@verse.people).to include(@person)
    post :destroy, {id: @verse.id}, {logged_in_id: @person.id}
    expect(response).to redirect_to(verse_path(@verse))
    @verse.reload
    expect(@verse.people).to_not include(@person)
  end

  it "should destroy the verse if there are no more people" do
    post :destroy, {id: @verse.id}, {logged_in_id: @person.id}
    expect(response).to redirect_to(verses_path)
    assert_raise(ActiveRecord::RecordNotFound) do
      @verse.reload
    end
  end

  it "should create a shared stream item when a verse is added and the owner is sharing their activity" do
    expect(StreamItem.where(streamable_type: "Verse", streamable_id: @verse.id).count).to eq(0)
    post :create, {id: @verse.id}, {logged_in_id: @other_person.id}
    items = StreamItem.where(streamable_type: "Verse", streamable_id: @verse.id).to_a
    expect(items.length).to eq(1)
    expect(items.first.person).to eq(@other_person)
    expect(items.first).to be_shared
  end

  it "should create a non-shared stream item when a verse is added and the owner is not sharing their activity" do
    @other_person.update_attributes! share_activity: false
    expect(StreamItem.where(streamable_type: "Verse", streamable_id: @verse.id).count).to eq(0)
    post :create, {id: @verse.id}, {logged_in_id: @other_person.id}
    items = StreamItem.where(streamable_type: "Verse", streamable_id: @verse.id).to_a
    expect(items.length).to eq(1)
    expect(items.first.person).to eq(@other_person)
    expect(items.first).to_not be_shared
  end

  it "should delete all associated stream items when a verse is removed" do
    post :create, {id: @verse.id}, {logged_in_id: @other_person.id}
    expect(StreamItem.where(streamable_type: "Verse", streamable_id: @verse.id).count).to eq(1)
    post :destroy, {id: @verse.id}, {logged_in_id: @other_person.id}
    expect(StreamItem.where(streamable_type: "Verse", streamable_id: @verse.id).count).to eq(0)
  end

end
