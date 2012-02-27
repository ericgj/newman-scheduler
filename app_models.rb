
Dir[File.expand_path('app/models/*.rb', File.dirname(__FILE__))].each do |f|
  require f
end
