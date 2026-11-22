import { qs, showToast } from '../utils/dom';
import { renderBottomNav } from '../utils/bottom-nav';

qs('#nav-slot')?.replaceWith(renderBottomNav('home'));
qs('#toast-btn')?.addEventListener('click', () => showToast('저장했어요'));
