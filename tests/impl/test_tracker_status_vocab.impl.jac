impl TrackerStatusVocabulary.test_each_section_states_its_status_spellings {
    for (name, heading, present, absent) in CASES {
        with self.subTest(command=name, heading=heading) {
            text: str = command(name);
            check(self, under(text, heading) if heading else text, present, absent);
        }
    }
}
