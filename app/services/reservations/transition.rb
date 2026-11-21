# frozen_string_literal: true

module Reservations
  # The single place a reservation changes status, so the webhook, the payment sync and the expiry
  # job cannot disagree. Returns true when the move was made, false for any move not in ALLOWED
  # (including a move to the current state), in which case nothing is changed. With from:, the move
  # is also refused unless the locked, reloaded status equals from (the caller's view is not stale).
  class Transition
    ALLOWED = {
      'pending_payment' => %w[confirmed expired cancelled],
      'confirmed' => %w[cancelled]
    }.freeze

    def self.call(reservation, to:, reason:, from: nil)
      new(reservation, to: to, reason: reason, from: from).call
    end

    def initialize(reservation, to:, reason:, from: nil)
      @reservation = reservation
      @to = to.to_s
      @reason = reason
      @expected_from = from&.to_s
    end

    def call
      moved = @reservation.with_lock do
        next false unless allowed?

        apply
        true
      end
      return false unless moved

      # The boarding-pass email is queued by Reservation's after_commit callback, so it only goes
      # out once the change is really committed, even when the caller holds an outer transaction.
      Rails.logger.info "[Reservations::Transition] #{@reservation.uid} #{@from} -> #{@to} (#{@reason})"
      true
    end

    private

    def allowed?
      @from = @reservation.status
      return false if @expected_from && @expected_from != @from

      ALLOWED.fetch(@from, []).include?(@to)
    end

    def apply
      attrs = { status: @to }
      attrs[:cancelled_at] = Time.current if @to == 'cancelled'
      @reservation.update!(attrs)
      @reservation.schedule.increment_available_seat! if %w[expired cancelled].include?(@to)
    end
  end
end
