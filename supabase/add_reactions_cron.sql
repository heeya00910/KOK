SELECT cron.schedule('collect_reactions_1', '40 23 * * *', $$SELECT invoke_pipeline_stage('collect_reactions')$$);
SELECT cron.schedule('collect_reactions_2', '40 5 * * *', $$SELECT invoke_pipeline_stage('collect_reactions')$$);
SELECT cron.schedule('collect_reactions_3', '40 12 * * *', $$SELECT invoke_pipeline_stage('collect_reactions')$$);
