-- Habits table
CREATE TABLE IF NOT EXISTS public.habits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Daily logs table (one per user per date)
CREATE TABLE IF NOT EXISTS public.daily_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, date)
);

-- Log entries (Yes/No per habit within a daily log)
CREATE TABLE IF NOT EXISTS public.log_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  log_id uuid NOT NULL REFERENCES public.daily_logs(id) ON DELETE CASCADE,
  habit_id uuid NOT NULL REFERENCES public.habits(id) ON DELETE CASCADE,
  value boolean NOT NULL,
  UNIQUE (log_id, habit_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS habits_user_id_idx ON public.habits(user_id);
CREATE INDEX IF NOT EXISTS daily_logs_user_id_date_idx ON public.daily_logs(user_id, date DESC);
CREATE INDEX IF NOT EXISTS log_entries_log_id_idx ON public.log_entries(log_id);
CREATE INDEX IF NOT EXISTS log_entries_habit_id_idx ON public.log_entries(habit_id);

-- Enable RLS
ALTER TABLE public.habits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.log_entries ENABLE ROW LEVEL SECURITY;

-- Habits policies
CREATE POLICY "Users can view own habits"
  ON public.habits FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own habits"
  ON public.habits FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own habits"
  ON public.habits FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own habits"
  ON public.habits FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Daily logs policies
CREATE POLICY "Users can view own daily_logs"
  ON public.daily_logs FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own daily_logs"
  ON public.daily_logs FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own daily_logs"
  ON public.daily_logs FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own daily_logs"
  ON public.daily_logs FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Log entries policies (scoped via parent daily_log ownership)
CREATE POLICY "Users can view own log_entries"
  ON public.log_entries FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.daily_logs
      WHERE daily_logs.id = log_entries.log_id
        AND daily_logs.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own log_entries"
  ON public.log_entries FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.daily_logs
      WHERE daily_logs.id = log_entries.log_id
        AND daily_logs.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update own log_entries"
  ON public.log_entries FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.daily_logs
      WHERE daily_logs.id = log_entries.log_id
        AND daily_logs.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.daily_logs
      WHERE daily_logs.id = log_entries.log_id
        AND daily_logs.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete own log_entries"
  ON public.log_entries FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.daily_logs
      WHERE daily_logs.id = log_entries.log_id
        AND daily_logs.user_id = auth.uid()
    )
  );
