require 'spec_helper' 

feature "Editing collections" do 
  before :all do 
    @root = FactoryGirl.create(:root_collection)
    @collection = FactoryGirl.create(:valid_owned_by_bill)
    # @minimal_collection = FactoryGirl.create(:minimal_valid_collection)
    @user = FactoryGirl.create(:bill) 
  end

  # Assign reused lookup code to clean up test appearance a bit. 
  let(:creator_firsts) { page.all('input#nu_collection_creator_first_name') } 
  let(:creator_lasts) { page.all('input#nu_collection_creator_last_name') } 
  let(:corporate_creators) { page.all('input#nu_collection_corporate_creators') }
  let(:keywords) { page.all('input#nu_collection_keywords') }  

  scenario "Collection data preloads correctly in edit screen" do 
    sign_in @user 

    visit edit_nu_collection_path(@collection)

    #Verify data prefills correctly
    find_field('Title:').value.should == 'Bills Collection'
    find_field('Description:').value.should == 'Bills new collection' 
    find_field('Date of Issuance').value.should == Date.yesterday.to_s 

    # Personal creator names 
    creator_firsts.at(0).value.should == "David" 
    creator_firsts.at(1).value.should == "Steven" 
    creator_firsts.at(2).value.should == "Will" 
    creator_lasts.at(0).value.should == "Cliff"
    creator_lasts.at(1).value.should == "Bassett" 
    creator_lasts.at(2).value.should == "Jackson" 

    # Corporate creator names
    corporate_creators.at(0).value.should == "Corp One" 
    corporate_creators.at(1).value.should == "Corp Two" 
    corporate_creators.at(2).value.should == "Corp Three"

    # Keywords 
    keywords.at(0).value.should == "kw one"  
    keywords.at(1).value.should == "kw two" 
    keywords.at(2).value.should == "kw three" 

    find_field('Choose Mass Permissions:').value.should == 'public'      
  end

  # Objects instantiated in before :all hooks aren't cleaned up by rails transactional behavior.
  # Fedora objects are generally not rolled back either. 
  after :all do 
    @root.destroy 
    @collection.destroy
    @user.destroy 
  end
end 