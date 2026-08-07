from pathlib import Path

# Test 04: profile simulation changes must not navigate away from Settings.
path = Path('lib/src/presentation/screens/time_records_screen.dart')
text = path.read_text()
old = """        setState(() {
          _destination =
              {
                PilotRole.owner,
                PilotRole.administrator,
                PilotRole.coordinator,
                PilotRole.supervisor,
              }.contains(role)
              ? _Destination.management
              : _Destination.home;
        });
"""
new = """        // Keep the user inside Settings after changing the simulated
        // profile. The new identity is reflected when they intentionally
        // navigate to Home, Timesheet, Management, or another section.
        if (mounted) {
          setState(() => _destination = _Destination.settings);
        }
"""
if old not in text:
    raise RuntimeError('Simulation navigation block not found')
path.write_text(text.replace(old, new, 1))
