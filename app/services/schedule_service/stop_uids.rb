# frozen_string_literal: true

module ScheduleService
  # Turns the `from_stop_uid` / `to_stop_uid` request params into stop ids. Only keys that were
  # sent are returned, so an update without them leaves the stops alone; a blank uid clears the stop.
  module StopUids
    STOP_ID_KEYS = { from_stop_uid: :from_stop_id, to_stop_uid: :to_stop_id }.freeze

    private

    # Returns a Hash of ids, or false (with an error added) when a uid matches no stop.
    def resolve_stop_ids
      STOP_ID_KEYS.each_with_object({}) do |(uid_key, id_key), ids|
        next unless params.key?(uid_key)

        uid = params[uid_key]
        if uid.blank?
          ids[id_key] = nil
          next
        end

        stop = Stop.find_by(uid: uid)
        return add_error('schedule.stop_not_found', uid: uid) unless stop

        ids[id_key] = stop.id
      end
    end
  end
end
