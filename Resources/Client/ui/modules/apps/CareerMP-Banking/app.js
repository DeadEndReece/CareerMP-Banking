var app = angular.module('beamng.apps');

function careerMPBankingEscapeLuaString(value) {
	return String(value || '')
		.replace(/\\/g, '\\\\')
		.replace(/"/g, '\\"')
		.replace(/\n/g, '\\n')
		.replace(/\r/g, '\\r');
}

function careerMPBankingFormatMoney(value, forceTwoDecimals) {
	const amount = Number(value) || 0;
	const shouldShowDecimals = forceTwoDecimals || !Number.isInteger(amount);
	return '$' + amount.toLocaleString(undefined, {
		minimumFractionDigits: shouldShowDecimals ? 2 : 0,
		maximumFractionDigits: shouldShowDecimals ? 2 : 0
	});
}

app.directive('careermpbanking', [function () {
	return {
		templateUrl: '/ui/modules/apps/CareerMP-Banking/app.html',
		replace: true,
		restrict: 'EA',
		scope: true
	};
}]);

app.controller('CareerMPBankingController', ['$scope', '$interval', function ($scope, $interval) {
	const panelTransitionMs = 180;
	$scope.balance = 0;
	$scope.players = [];
	$scope.visiblePlayers = [];
	$scope.receiveEnabled = true;
	$scope.transferAmount = 100;
	$scope.nickname = '';
	$scope.paymentAllowed = false;
	$scope.amountPresets = [100, 1000, 5000, 10000];
	let hidePanelTimer = null;

	function updateButtonHeight() {
		const root = document.querySelector('.careermp-banking-root');
		const button = document.getElementById('banking-show-button');
		if (!root || !button) {
			return;
		}

		const isVerticalDock = root.classList.contains('is-left-anchored') || root.classList.contains('is-right-anchored');
		button.style.width = isVerticalDock ? '28px' : '75px';
		button.style.height = isVerticalDock ? '75px' : '28px';
	}

	function clearHidePanelTimer() {
		if (!hidePanelTimer) {
			return;
		}

		clearTimeout(hidePanelTimer);
		hidePanelTimer = null;
	}

	function setDockSide(side) {
		const root = document.querySelector('.careermp-banking-root');
		if (!root) {
			return;
		}

		root.classList.toggle('is-left-anchored', side === 'left');
		root.classList.toggle('is-right-anchored', side === 'right');
		root.classList.toggle('is-top-anchored', side === 'top');
		root.classList.toggle('is-bottom-anchored', side === 'bottom');
	}

	function updateDockOrientation() {
		const root = document.querySelector('.careermp-banking-root');
		if (!root || !window.innerWidth || !window.innerHeight) {
			return;
		}

		const rect = root.getBoundingClientRect();
		const distances = [
			{ side: 'left', distance: rect.left },
			{ side: 'right', distance: window.innerWidth - rect.right },
			{ side: 'top', distance: rect.top },
			{ side: 'bottom', distance: window.innerHeight - rect.bottom }
		];

		distances.sort(function (left, right) {
			return left.distance - right.distance;
		});

		setDockSide(distances[0].side);
		updateButtonHeight();
	}

	function showPanel() {
		const container = document.getElementById('banking-container');
		const button = document.getElementById('banking-show-button');
		if (!container || !button) {
			return;
		}

		clearHidePanelTimer();
		container.style.display = 'block';
		updateDockOrientation();
		void container.offsetWidth;
		container.classList.add('is-open');
		button.textContent = 'B';
		localStorage.setItem('careermpBankingShown', '1');
		refreshState();
		setTimeout(updateButtonHeight, 0);
	}

	function hidePanel(immediate) {
		const container = document.getElementById('banking-container');
		const button = document.getElementById('banking-show-button');
		if (!container || !button) {
			return;
		}

		clearHidePanelTimer();
		container.classList.remove('is-open');
		button.textContent = 'B';
		updateButtonHeight();
		localStorage.setItem('careermpBankingShown', '0');
		setCefFocus(false);

		if (immediate) {
			container.style.display = 'none';
			return;
		}

		hidePanelTimer = setTimeout(function () {
			if (!container.classList.contains('is-open')) {
				container.style.display = 'none';
			}
			hidePanelTimer = null;
		}, panelTransitionMs);
	}

	function applyState(data) {
		let parsed = data;
		if (typeof parsed === 'string') {
			try {
				parsed = JSON.parse(parsed);
			} catch (error) {
				return;
			}
		}

		if (!parsed) {
			return;
		}

		$scope.balance = Number(parsed.balance) || 0;
		$scope.players = Array.isArray(parsed.players) ? parsed.players : [];
		$scope.visiblePlayers = $scope.players.filter(function (player) {
			return player && !player.isSelf;
		});
		$scope.receiveEnabled = parsed.receiveEnabled !== false;
		$scope.nickname = parsed.nickname || '';
		$scope.paymentAllowed = parsed.paymentAllowed !== false;
		$scope.$evalAsync();
		setTimeout(function () {
			updateDockOrientation();
		}, 0);
	}

	function refreshState() {
		bngApi.engineLua('careerMPBanking.getUiState()', applyState);
	}

	function setCefFocus(focused) {
		bngApi.engineLua('setCEFFocus(' + (focused ? 'true' : 'false') + ')');
	}

	$scope.formatMoney = careerMPBankingFormatMoney;
	$scope.togglePanel = function () {
		if (localStorage.getItem('careermpBankingShown') === '1') {
			hidePanel();
		} else {
			showPanel();
		}
	};
	$scope.engageFocus = function () {
		setCefFocus(true);
	};
	$scope.releaseFocus = function () {
		setCefFocus(false);
	};

	$scope.setTransferAmount = function (amount) {
		$scope.transferAmount = amount;
	};

	$scope.getDisplayName = function (player) {
		return player.formatted_name || player.name || ('Player ' + player.id);
	};

	$scope.canSendToPlayer = function (player) {
		const amount = parseInt($scope.transferAmount, 10);
		return !!player && !player.isSelf && Number.isFinite(amount) && amount > 0 && $scope.balance >= amount && $scope.paymentAllowed;
	};

	$scope.sendPayment = function (player) {
		const amount = parseInt($scope.transferAmount, 10);
		if (!Number.isFinite(amount) || amount <= 0 || !player || player.isSelf) {
			return;
		}

		bngApi.engineLua('careerMPBanking.payPlayer("' + careerMPBankingEscapeLuaString(player.name) + '", ' + amount + ')');
		refreshState();
		setTimeout(refreshState, 300);
	};

	$scope.toggleReceiving = function () {
		$scope.receiveEnabled = !$scope.receiveEnabled;
		bngApi.engineLua('careerMPBanking.setReceiveEnabled(' + ($scope.receiveEnabled ? 'true' : 'false') + ')');
		refreshState();
	};

	const refreshTimer = $interval(refreshState, 1000);
	const dockTimer = $interval(updateDockOrientation, 250);
	refreshState();
	setTimeout(function () {
		updateDockOrientation();
		hidePanel(true);
	}, 0);

	$scope.$on('$destroy', function () {
		clearHidePanelTimer();
		setCefFocus(false);
		$interval.cancel(refreshTimer);
		$interval.cancel(dockTimer);
	});
}]);
