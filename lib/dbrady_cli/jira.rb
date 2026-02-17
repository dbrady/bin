module DbradyCli
  # get the jira ticket (board and id, e.g. PANTS-44) from given branch or git
  # current-branch
  def jira_ticket(branch=nil)
    branch ||= git_current_branch

    branch.split(%r{/})[1].split(%r{-})[0..1].join('-').to_s
  end

  # get url to ticket
  def jira_url(ticket=jira_ticket)
    "https://upbd.atlassian.net/browse/#{ticket}"
  end

  # Generate the markdown linkety blurb
  def markdown_link_to_jira_ticket(ticket=jira_ticket)
    "Link to Ticket: [#{jira_ticket}](#{jira_url})"
  end
end
