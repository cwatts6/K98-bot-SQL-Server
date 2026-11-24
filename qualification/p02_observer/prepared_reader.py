"""Prepared physical reader connections; one original observation budget."""

from scripts.verify_k98_running_release import ObservationConnections


class PreparedConnections(ObservationConnections):
    def __init__(self, connect):
        super().__init__(connect)
        self.pending = []
        self.prepared = False

    def prepare(self):
        if self.prepared or self.pending or self.connections:
            raise ValueError("Reader preparation cannot repeat")
        self.prepared = True
        from importlib import import_module

        # Finish the exact reader's lazy imports before readiness as well. Their
        # time is charged to this same owner, not hidden outside its deadline.
        for name in (
            "scripts.verify_k98_update_pair",
            "services.application_observation_schedule",
            "services.observer_release_dal",
            "services.observer_release_issuance",
        ):
            import_module(name)
        self.check(dispatch=False)
        # The same actual owner tracks every raw connection and its SET cursor.
        # No catalogue comparison has run. Setup and waiting consume its 45 s.
        for _ in range(4):
            self.pending.append(super().__call__())
        self.check(dispatch=False)

    def __call__(self):
        self.check()
        if not self.prepared or not self.pending:
            raise ValueError("Exactly four prepared reader connections required")
        return self.pending.pop(0)
