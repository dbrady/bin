import os
import json

class BadTicket:
    """
    BadTicket

    Nomenclature consistency:

    If we say "number" it is an integer. Jira case DS-1406 would have number
    1406. If we say "ticket_id" it is the string of the ticket and include the
    team prefix, e.g. "DS-1406".
    """
    def __init__(self, id, comment=""):
        """
        number - jira case number, integer, e.g. "DS-1406" would be int(1406)
        comment - reason ticket should be skipped, e.g. "Blocked until finance connection exists"
        ticket_id - jira ticket id as a string, e.g. "DS-1406"
        """
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

    def ticket_exists(self, number):
        return number in [ticket.id for ticket in self.tickets]
