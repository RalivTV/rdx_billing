RDX = nil

TriggerEvent('rdx:getSharedObject', function(obj) RDX = obj end)

RegisterServerEvent('rdx_billing:sendBill')
AddEventHandler('rdx_billing:sendBill', function(playerId, sharedAccountName, label, amount)
	local _source = source
	local xPlayer = RDX.GetPlayerFromId(_source)
	local xTarget = RDX.GetPlayerFromId(playerId)
	amount        = RDX.Math.Round(amount)

	TriggerEvent('rdx_addonaccount:getSharedAccount', sharedAccountName, function(account)

		if amount < 0 then
			print(('rdx_billing: %s attempted to send a negative bill!'):format(xPlayer.identifier))
		elseif account == nil then

			if xTarget ~= nil then
				MySQL.Async.execute('INSERT INTO billing (identifier, sender, target_type, target, label, amount) VALUES (@identifier, @sender, @target_type, @target, @label, @amount)',
				{
					['@identifier']  = xTarget.identifier,
					['@sender']      = xPlayer.identifier,
					['@target_type'] = 'player',
					['@target']      = xPlayer.identifier,
					['@label']       = label,
					['@amount']      = amount
				}, function(rowsChanged)
					TriggerClientEvent('rdx:showNotification', xTarget.source, _U('received_invoice'))
				end)
			end

		else

			if xTarget ~= nil then
				MySQL.Async.execute('INSERT INTO billing (identifier, sender, target_type, target, label, amount) VALUES (@identifier, @sender, @target_type, @target, @label, @amount)',
				{
					['@identifier']  = xTarget.identifier,
					['@sender']      = xPlayer.identifier,
					['@target_type'] = 'society',
					['@target']      = sharedAccountName,
					['@label']       = label,
					['@amount']      = amount
				}, function(rowsChanged)
					TriggerClientEvent('rdx:showNotification', xTarget.source, _U('received_invoice'))
				end)
			end

		end
	end)

end)

RDX.RegisterServerCallback('rdx_billing:getBills', function(source, cb)
	local xPlayer = RDX.GetPlayerFromId(source)

	MySQL.Async.fetchAll('SELECT * FROM billing WHERE identifier = @identifier', {
		['@identifier'] = xPlayer.identifier
	}, function(result)
		local bills = {}
		for i=1, #result, 1 do
			table.insert(bills, {
				id         = result[i].id,
				identifier = result[i].identifier,
				sender     = result[i].sender,
				targetType = result[i].target_type,
				target     = result[i].target,
				label      = result[i].label,
				amount     = result[i].amount
			})
		end

		cb(bills)
	end)
end)

RDX.RegisterServerCallback('rdx_billing:getTargetBills', function(source, cb, target)
	local xPlayer = RDX.GetPlayerFromId(target)

	MySQL.Async.fetchAll('SELECT * FROM billing WHERE identifier = @identifier', {
		['@identifier'] = xPlayer.identifier
	}, function(result)
		local bills = {}
		for i=1, #result, 1 do
			table.insert(bills, {
				id         = result[i].id,
				identifier = result[i].identifier,
				sender     = result[i].sender,
				targetType = result[i].target_type,
				target     = result[i].target,
				label      = result[i].label,
				amount     = result[i].amount
			})
		end

		cb(bills)
	end)
end)


RDX.RegisterServerCallback('rdx_billing:payBill', function(source, cb, id)
	local xPlayer = RDX.GetPlayerFromId(source)

	MySQL.Async.fetchAll('SELECT * FROM billing WHERE id = @id', {
		['@id'] = id
	}, function(result)

		local sender     = result[1].sender
		local targetType = result[1].target_type
		local target     = result[1].target
		local amount     = result[1].amount

		local xTarget = RDX.GetPlayerFromIdentifier(sender)

		if targetType == 'player' then

			if xTarget ~= nil then

				if xPlayer.getMoney() >= amount then

					MySQL.Async.execute('DELETE from billing WHERE id = @id', {
						['@id'] = id
					}, function(rowsChanged)
						xPlayer.removeMoney(amount)
						xTarget.addMoney(amount)

						TriggerClientEvent('rdx:showNotification', xPlayer.source, _U('paid_invoice', RDX.Math.GroupDigits(amount)))
						TriggerClientEvent('rdx:showNotification', xTarget.source, _U('received_payment', RDX.Math.GroupDigits(amount)))

						cb()
					end)

				elseif xPlayer.getBank() >= amount then

					MySQL.Async.execute('DELETE from billing WHERE id = @id', {
						['@id'] = id
					}, function(rowsChanged)
						xPlayer.removeAccountMoney('bank', amount)
						xTarget.addAccountMoney('bank', amount)

						TriggerClientEvent('rdx:showNotification', xPlayer.source, _U('paid_invoice', RDX.Math.GroupDigits(amount)))
						TriggerClientEvent('rdx:showNotification', xTarget.source, _U('received_payment', RDX.Math.GroupDigits(amount)))

						cb()
					end)

				else
					TriggerClientEvent('rdx:showNotification', xTarget.source, _U('target_no_money'))
					TriggerClientEvent('rdx:showNotification', xPlayer.source, _U('no_money'))

					cb()
				end

			else
				TriggerClientEvent('rdx:showNotification', xPlayer.source, _U('player_not_online'))
				cb()
			end

		else

			TriggerEvent('rdx_addonaccount:getSharedAccount', target, function(account)

				if xPlayer.getMoney() >= amount then

					MySQL.Async.execute('DELETE from billing WHERE id = @id', {
						['@id'] = id
					}, function(rowsChanged)
						xPlayer.removeMoney(amount)
						account.addMoney(amount)

						TriggerClientEvent('rdx:showNotification', xPlayer.source, _U('paid_invoice', RDX.Math.GroupDigits(amount)))
						if xTarget ~= nil then
							TriggerClientEvent('rdx:showNotification', xTarget.source, _U('received_payment', RDX.Math.GroupDigits(amount)))
						end

						cb()
					end)

				elseif xPlayer.getBank() >= amount then

					MySQL.Async.execute('DELETE from billing WHERE id = @id', {
						['@id'] = id
					}, function(rowsChanged)
						xPlayer.removeAccountMoney('bank', amount)
						account.addMoney(amount)

						TriggerClientEvent('rdx:showNotification', xPlayer.source, _U('paid_invoice', RDX.Math.GroupDigits(amount)))
						if xTarget ~= nil then
							TriggerClientEvent('rdx:showNotification', xTarget.source, _U('received_payment', RDX.Math.GroupDigits(amount)))
						end

						cb()
					end)

				else
					TriggerClientEvent('rdx:showNotification', xPlayer.source, _U('no_money'))

					if xTarget ~= nil then
						TriggerClientEvent('rdx:showNotification', xTarget.source, _U('target_no_money'))
					end

					cb()
				end
			end)

		end

	end)
end)