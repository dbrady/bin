#!/usr/bin/env python
# jira.py - Dump out list of eligible next JIRA tickets. This is my sketch/burn/monkeypatch copy of DS Team's jira ticket reader.
# RUN THIS WITH next-ticket (or don't, I'm not your real Dad)
import argparse

from dataservices import jira
import json
import os

class BadTicket:
    """
    BadTicket
    number - jira case number, integer, e.g. "DS-1406" would be int(1406)
    comment - reason ticket should be skipped, e.g. "Blocked until finance connection exists"
    ticket_id - jira ticket id as a string, e.g. "DS-1406"
    """
    def __init__(self, id, comment=""):
        self.id = id
        self.comment = comment
        self.ticket_id = f"DS-{id}"

    def __str__(self):
        f"DS-{self.id}"


class BadTickets:
    def __init__(self):
        try:
            with open(os.path.expanduser("~/jira-bad-tickets.json")) as file:
                tickets = json.loads(file.read())["tickets"]
                self.tickets = [BadTicket(ticket["id"], ticket.get("comment", None)) for ticket in tickets]
        except FileNotFoundError:
            self.tickets = []

    def ids(self):
        return [ticket.ticket_id for ticket in self.tickets]


def get_bad_tickets():
    try:
        with open(os.path.expanduser("~/jira-bad-tickets.json")) as file:
            return json.loads(file.read())["tickets"]
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
    bad_tickets = BadTickets()
    bad_ticket_ids = bad_tickets.ids()
    print(bad_ticket_ids)

    while not finished:
        tickets = jira_client.find_issue_by_epic_id(ticket_number, fields=fields, start_at=start_at)
        print(f"FOUND {len(tickets)} TICKETS!")
        for ticket in tickets['issues']:
            # print(ticket['key'])
            ready = True
            issuelinks = ticket['fields']['issuelinks']
            for issue in issuelinks:
                if 'inwardIssue' in issue:
                    if issue['inwardIssue']['fields']['status']['statusCategory']['name'] != 'Done' or ticket['fields']['status']['statusCategory']['name'] != 'To Do':
                        ready = False

            # if ticket["key"] in bad_tickets <-- can we hijack the "in" operator?
            #
            # bad_ticket = bad_tickets.find(ticket["key"])
            # if bad_ticket is not None:
            #     print(f"skipping ticket {bad_ticket.id} because {bad_ticket.reason}")
            if ticket["key"] in bad_ticket_ids:
                # ticket = find_ticket(ticket["key"], bad_tickets)
                print(f'Skipping {ticket["key"]}: \033[2;37mhttps://acima.atlassian.net/browse/{ticket["key"]}\033[0m')
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

    # ready_for_dev = args.ready_for_dev or False
    ready_for_dev = True

    if ready_for_dev:
        find_ready_for_dev()
