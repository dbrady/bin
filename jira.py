#!/usr/bin/env python
# jira.py - my sketch/burn/monkeypatch copy of our jira ticket reader
import argparse

from dataservices import jira
import json
import os

def get_bad_tickets():
    try:
        with open(os.path.expanduser("~/jira-bad-tickets.json")) as file:
            return json.loads(file.read())
    except FileNotFoundError:
        return []

def find_ready_for_dev():
    # ticket_number = input('Epic ticket number with children tickets (ex: DS-879): ')
    # if ticket_number == '':
    #     ticket_number = 'DS-879'
    ticket_number = 'DS-879'

    jira_client = jira.Jira()
    fields = 'issuelinks,status'
    finished = None
    start_at = 0
    dave_count = 0
    dave_max = 10
    bad_tickets = get_bad_tickets()
    bad_tickets = [f"DS-{ticket_id}" for ticket_id in bad_tickets]
    print(bad_tickets)
    while not finished:
        tickets = jira_client.find_issue_by_epic_id(ticket_number, fields=fields, start_at=start_at)
        for ticket in tickets['issues']:
            ready = True
            issuelinks = ticket['fields']['issuelinks']
            for issue in issuelinks:
                if 'inwardIssue' in issue:
                    if issue['inwardIssue']['fields']['status']['statusCategory']['name'] != 'Done' or ticket['fields']['status']['statusCategory']['name'] != 'To Do':
                        ready = False

            if ticket["key"] in bad_tickets:
                print(f"Skipping {ticket['key']}")
                continue

            if ready:
                dave_count += 1
                print(f'https://acima.atlassian.net/browse/{ticket["key"]}')
                if dave_count >= dave_max:
                    finished = True
                    break

        start_at = tickets['startAt'] + tickets['maxResults']
        dave_count = dave_count + 1
        if start_at >= tickets['total']:
            finished = True


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Manage the incremental process')
    parser.add_argument(
        '--ready_for_dev', action='store_true', help='Find tickets that are ready for development', required=False)
    args = parser.parse_args()

    ready_for_dev = args.ready_for_dev or False

    if ready_for_dev:
        find_ready_for_dev()
