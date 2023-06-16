SELECT text_questions.id, text_questions.title, text_questions.body, text_answers.id, text_answers.body
FROM public.text_questions
join public.text_answers on text_questions.id = text_answers.text_question_id
where text_questions.is_answered = true
and text_questions.image is null
ORDER BY text_questions.id ASC