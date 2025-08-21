/**
 * 禁用浏览器默认右键菜单工具
 * 用于避免与 Flutter 自定义右键菜单功能冲突
 */

(function() {
  'use strict';
  
  // 全局禁用右键菜单
  function disableContextMenu() {
    document.addEventListener('contextmenu', function(e) {
      e.preventDefault();
      e.stopPropagation();
      return false;
    }, true);
    
    // 阻止右键菜单的键盘快捷键
    document.addEventListener('keydown', function(e) {
      // 阻止 F10 键（Windows 默认右键菜单快捷键）
      if (e.key === 'F10') {
        e.preventDefault();
        return false;
      }
      
      // 阻止 Shift + F10 组合键
      if (e.shiftKey && e.key === 'F10') {
        e.preventDefault();
        return false;
      }
    });
    
    console.log('🚫 浏览器默认右键菜单已禁用');
  }
  
  // 为特定元素禁用右键菜单
  function disableContextMenuForElement(selector) {
    const elements = document.querySelectorAll(selector);
    elements.forEach(function(element) {
      element.addEventListener('contextmenu', function(e) {
        e.preventDefault();
        e.stopPropagation();
        return false;
      });
    });
    
    console.log(`🚫 已为 ${elements.length} 个元素禁用右键菜单: ${selector}`);
  }
  
  // 为特定元素启用右键菜单（如果需要的话）
  function enableContextMenuForElement(selector) {
    const elements = document.querySelectorAll(selector);
    elements.forEach(function(element) {
      element.addEventListener('contextmenu', function(e) {
        e.stopPropagation();
        // 不阻止默认行为，允许浏览器右键菜单
      });
    });
    
    console.log(`✅ 已为 ${elements.length} 个元素启用右键菜单: ${selector}`);
  }
  
  // 页面加载完成后执行
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
      disableContextMenu();
      
      // 为 Flutter 应用区域禁用右键菜单
      disableContextMenuForElement('#flutter_target');
      disableContextMenuForElement('.flutter-app');
      
      // 为测试区域禁用右键菜单
      disableContextMenuForElement('.test-container');
      
      console.log('🎯 右键菜单控制已初始化完成');
    });
  } else {
    // 页面已经加载完成
    disableContextMenu();
    console.log('🎯 右键菜单控制已初始化完成（页面已加载）');
  }
  
  // 导出函数供外部使用
  window.ContextMenuControl = {
    disable: disableContextMenu,
    disableFor: disableContextMenuForElement,
    enableFor: enableContextMenuForElement
  };
  
})();
