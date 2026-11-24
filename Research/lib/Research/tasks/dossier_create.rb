# dossier_create — first revision of a scientific record.
#
# Creates the dossier and revision 1: allocates a root-local ID (Ids),
# stages the entry document README.md (Manager ruling 1) and commits it
# through the Store transaction protocol. With no `content` a short
# title-only outline is written — a SUGGESTION, never schema: the store
# demands only that some README.md bytes exist.
#
# idempotent-or-reject at the record level (design decision D2):
# IDs are allocated under the root lock and never reused, so a retried
# create for the same title either is a new dossier or returns an
# already-created one; nothing about the caller's retry count can
# corrupt the record space. No scientific status, no observation links,
# no required structure are imposed here.

require_relative 'common'

module Research
  input :type, :select, 'Kind of dossier to create; fixes the ID prefix: question Q-###, claim C-###, hypothesis H-###', nil, select_options: %w[question claim hypothesis]
  input :title, :string, 'Dossier title (written as the entry heading when content is omitted)'
  input :content, :text, 'Optional initial Markdown for the entry document README.md', nil, nofile: true
  desc 'Create a scientific record dossier (question, claim or hypothesis) and its first revision. Returns the root-local ID, revision, entry document README.md and a Markdown link to it.'
  task :dossier_create do |type, title, content|
    root = Tasks.store_root
    type = Tasks.parse_type!(type)

    title = title.to_s
    if title.strip.empty?
      raise ParameterException, 'title is required and must not be blank'
    end
    Tasks.reject_placeholder_text!(title, 'title')
    Tasks.reject_placeholder_text!(content, 'content') unless content.nil?

    body = content.nil? ? Research.outline_for(type, title) : content.to_s
    Tasks.reject_placeholder_text!(body, 'content')

    result = Tasks.map_store_errors(root) do
      id = Ids.allocate(root, type)
      Store.transaction(root, type, id,
                        expected_revision: 0, allow_create: true) do |ctx|
        ctx.change_note = nil
        ctx.write_document(Layout::DOC, body)
      end.merge('id' => id, 'type' => type)
    end

    dir = Layout.dossier_dir(root, type, result['id'])
    entry = Layout.doc_path(dir)
    {
      'id' => result['id'],
      'type' => result['type'],
      'revision' => result['revision'],
      'changed' => result['changed'],
      'entry_document' => Tasks.public_document_name(Layout::DOC),
      'link' => "[#{result['id']}](#{entry})"
    }
  end

  # Short title-only outline. Template is a suggestion: no structure
  # is required and none of this is schema.
  def Research.outline_for(type, title)
    label = Ids::TYPES.keys.include?(type) ? type : 'record'
    "# #{title}\n\n#{label.capitalize} record created by dossier_create. " \
      "Replace this outline through dossier_update.\n"
  end
# internal helpers (module functions reached from the task body as Research.<name>)
  export_exec :dossier_create
end
