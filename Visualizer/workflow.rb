require 'scout-ai'

module Visualizer
  extend Workflow
  self.include_workflow AgentWorkflow

  desc <<-EOF
Create an image following a prompt

The image will be created in the path specified by the input file_path, and
will be subject to sandboxing rules.
  EOF
  input :file_path, :path, "File path of image to create", nil, required: true
  input :prompt, :text, "Prompt for the image generation", nil, required: true
  input :size, :text, "Size of the image", '1024x1024'
  input :quality, :text, "Quality of the image", 'medium'
  task :create_image => :string do |file_path,prompt,size|
    file_path = Path.setup(file_path) unless Path === file_path
    file_path = file_path.find(:current) unless file_path.located?
    LLM::Sandbox.authorize_path file_path, base_path: Dir.pwd
    agent = self.agent start_chat: Scout.root.start_chat.find(:lib), endpoint: 'terra', model: 'gpt-image-2.5-flare'
    agent.user prompt
    agent.create_image file_path, quality: 'medium', size: size
    "File created at #{file_path}"
  end

end

