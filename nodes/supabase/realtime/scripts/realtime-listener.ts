import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_ANON_KEY!
);

const table = process.argv[2] || 'messages';
const channelName = `${table}-realtime`;

console.log(`Subscribing to changes on '${table}'...`);

const channel = supabase
  .channel(channelName)
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'public',
      table: table,
    },
    (payload) => {
      const timestamp = new Date().toISOString();
      console.log(`[${timestamp}] ${payload.eventType}:`);

      if (payload.eventType === 'INSERT') {
        console.log('  New row:', JSON.stringify(payload.new, null, 2));
      } else if (payload.eventType === 'UPDATE') {
        console.log('  Old:', JSON.stringify(payload.old, null, 2));
        console.log('  New:', JSON.stringify(payload.new, null, 2));
      } else if (payload.eventType === 'DELETE') {
        console.log('  Deleted:', JSON.stringify(payload.old, null, 2));
      }
    }
  )
  .subscribe((status) => {
    console.log(`Channel status: ${status}`);
    if (status === 'SUBSCRIBED') {
      console.log(`Listening for changes on '${table}'... (Ctrl+C to stop)`);
    }
    if (status === 'CHANNEL_ERROR') {
      console.error('Channel error. Check that the table is in the realtime publication:');
      console.error(`  ALTER PUBLICATION supabase_realtime ADD TABLE ${table};`);
    }
  });

// Keep process alive
process.on('SIGINT', async () => {
  console.log('\nUnsubscribing...');
  await supabase.removeChannel(channel);
  process.exit(0);
});
