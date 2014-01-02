def mint_unique_pid 
  Sufia::Noid.namespaceize(Sufia::IdService.mint)
end

def create_collection(klass, parent_str, title_str, description = "Lorem ipsum dolor sit amet, consectetur adipisicing elit. Recusandae, minima, cum sit iste at mollitia voluptatem error perspiciatis excepturi ut voluptatibus placeat esse architecto ea voluptate assumenda repudiandae quod commodi.")
  newPid = mint_unique_pid
  col = klass.new(parent: parent_str, pid: newPid, identifier: newPid, title: title_str, description: description)

  col.rightsMetadata.permissions({group: 'public'}, 'read')
  col.save!

  set_edit_permissions(col)

  return col
end 

def create_file(file_name, user, parent)
  newPid = mint_unique_pid

  core_record = NuCoreFile.new(depositor: "#{user.nuid}", pid: newPid, identifier: newPid, title: file_name)

  # Attach some keywords to make objects searchable/facetable on them. 
  core_record.keywords = ["system", "generated", "Random Object"] 
  core_record.mods.subject(2).topic.authority = "IMF" 
  core_record.set_parent(parent, user)
  core_record.save!

  set_edit_permissions(core_record)

  file_path = "#{Rails.root}/spec/fixtures/files/#{file_name}"

  Sufia.queue.push(ContentCreationJob.new(newPid, file_path, file_name, user.id, false))  
end

def create_content_file(factory_sym, user, parent) 
  master = FactoryGirl.create(factory_sym) 
  core   = master.core_record 

  master.mass_permissions = 'public'
  master.depositor = user.nuid
  DerivativeCreator.new(master.pid).generate_derivatives
  
  # Add non garbage metadata to core record. 
  core.parent = ActiveFedora::Base.find(parent.pid, cast: true) 
  core.title = "#{master.content.label}" 
  core.description = "Lorem Ipsum Lorem Ipsum Lorem Ipsum" 
  core.date_of_issue = Date.today.to_s
  core.depositor = user.nuid 
  core.mass_permissions = 'public'
  core.keywords = ["#{master.class}", "content"] 
  core.mods.subject(0).topic = "a"

  core.save! 
  master.save! 
end

def set_edit_permissions(obj)
  admin_users = ["001967405", "001905497", "000513515", "000000000"]

  admin_users.each do |nuid|
    obj.rightsMetadata.permissions({person: nuid}, 'edit')
    obj.save!
  end
end

task :reset_data => :environment do

  require 'factory_girl_rails' 

  ActiveFedora::Base.find(:all).each do |file|
    file.destroy 
  end

  User.find(:all).each do |user|
    user.destroy
  end

  root_dept = Community.new(pid: 'neu:1', identifier: 'neu:1', title: 'Northeastern University', description: "Founded in 1898, Northeastern is a global, experiential, research university built on a tradition of engagement with the world, creating a distinctive approach to education and research. The university offers a comprehensive range of undergraduate and graduate programs leading to degrees through the doctorate in nine colleges and schools, and select advanced degrees at graduate campuses in Charlotte, North Carolina, and Seattle.")
  root_dept.rightsMetadata.permissions({group: 'public'}, 'read')

  tmp_user = User.find_by_email("drsadmin@neu.edu")

  if !tmp_user.nil?
    tmp_user.destroy
  end
  
  tmp_user = User.create(email:"drsadmin@neu.edu", :password => "drs12345", :password_confirmation => "drs12345", full_name:"Temp User", nuid:"000000000")
  tmp_user.role = "admin"
  tmp_user.view_pref = "list"
  tmp_user.save!

  Sufia.queue.push(EmployeeCreateJob.new(tmp_user.nuid))
  
  set_edit_permissions(root_dept)

  engDept = create_collection(Community, 'neu:1', 'English Department')
  sciDept = create_collection(Community, 'neu:1', 'Science Department')
  litCol = create_collection(NuCollection, engDept.id, 'Literature')
  roCol = create_collection(NuCollection, engDept.id, 'Random Objects')
  rusNovCol = create_collection(NuCollection, litCol.id, 'Russian Novels') 

  create_file("test_docx.docx", tmp_user, roCol)
  create_file("test_pic.jpeg", tmp_user, roCol)
  create_file("test.pdf", tmp_user, roCol)

  create_content_file(:image_master_file, tmp_user, litCol) 
  create_content_file(:pdf_file, tmp_user, litCol) 
  create_content_file(:docx_file, tmp_user, litCol) 

  puts "Reset to stock objects complete."

end