/****************************************************************************
**
** Copyright (C) 2016 The Qt Company Ltd.
** Contact: https://www.qt.io/licensing/
**
** This file is part of the plugins of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:LGPL$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and The Qt Company. For licensing terms
** and conditions see https://www.qt.io/terms-conditions. For further
** information use the contact form at https://www.qt.io/contact-us.
**
** GNU Lesser General Public License Usage
** Alternatively, this file may be used under the terms of the GNU Lesser
** General Public License version 3 as published by the Free Software
** Foundation and appearing in the file LICENSE.LGPL3 included in the
** packaging of this file. Please review the following information to
** ensure the GNU Lesser General Public License version 3 requirements
** will be met: https://www.gnu.org/licenses/lgpl-3.0.html.
**
** GNU General Public License Usage
** Alternatively, this file may be used under the terms of the GNU
** General Public License version 2.0 or (at your option) the GNU General
** Public license version 3 or any later version approved by the KDE Free
** Qt Foundation. The licenses are as published by the Free Software
** Foundation and appearing in the file LICENSE.GPL2 and LICENSE.GPL3
** included in the packaging of this file. Please review the following
** information to ensure the GNU General Public License requirements will
** be met: https://www.gnu.org/licenses/gpl-2.0.html and
** https://www.gnu.org/licenses/gpl-3.0.html.
**
** $QT_END_LICENSE$
**
****************************************************************************/

#include "qcocoabackingstore.h"
#include <QtGui/QPainter>
#include "qcocoahelpers.h"

QT_BEGIN_NAMESPACE

QCocoaBackingStore::QCocoaBackingStore(QWindow *window)
    : QPlatformBackingStore(window)
{
}

QCocoaBackingStore::~QCocoaBackingStore()
{
    if (QCocoaWindow *cocoaWindow = static_cast<QCocoaWindow *>(window()->handle()))
        [cocoaWindow->m_qtView clearBackingStore:this];
}

QPaintDevice *QCocoaBackingStore::paintDevice()
{
    QCocoaWindow *cocoaWindow = static_cast<QCocoaWindow *>(window()->handle());
    int windowDevicePixelRatio = int(cocoaWindow->devicePixelRatio());

    // Receate the backing store buffer if the effective buffer size has changed,
    // either due to a window resize or devicePixelRatio change.
    QSize effectiveBufferSize = m_requestedSize * windowDevicePixelRatio;
    if (m_qImage.size() != effectiveBufferSize) {
        QImage::Format format = (window()->format().hasAlpha() || cocoaWindow->m_drawContentBorderGradient)
                ? QImage::Format_ARGB32_Premultiplied : QImage::Format_RGB32;
        m_qImage = QImage(effectiveBufferSize, format);
        m_qImage.setDevicePixelRatio(windowDevicePixelRatio);
        if (format == QImage::Format_ARGB32_Premultiplied)
            m_qImage.fill(Qt::transparent);
    }
    return &m_qImage;
}

void QCocoaBackingStore::flush(QWindow *win, const QRegion &region, const QPoint &offset)
{
    if (!m_qImage.isNull()) {
        if (QCocoaWindow *cocoaWindow = static_cast<QCocoaWindow *>(win->handle()))
            [cocoaWindow->m_qtView flushBackingStore:this region:region offset:offset];
    }
}

QImage QCocoaBackingStore::toImage() const
{
    return m_qImage;
}

void QCocoaBackingStore::resize(const QSize &size, const QRegion &)
{
    m_requestedSize = size;
}

bool QCocoaBackingStore::scroll(const QRegion &area, int dx, int dy)
{
    extern void qt_scrollRectInImage(QImage &img, const QRect &rect, const QPoint &offset);
    const qreal devicePixelRatio = m_qImage.devicePixelRatio();
    QPoint qpoint(dx * devicePixelRatio, dy * devicePixelRatio);
    for (const QRect &rect : area) {
        const QRect qrect(rect.topLeft() * devicePixelRatio, rect.size() * devicePixelRatio);
        qt_scrollRectInImage(m_qImage, qrect, qpoint);
    }
    return true;
}

void QCocoaBackingStore::beginPaint(const QRegion &region)
{
    if (m_qImage.hasAlphaChannel()) {
        QPainter p(&m_qImage);
        p.setCompositionMode(QPainter::CompositionMode_Source);
        const QColor blank = Qt::transparent;
        for (const QRect &rect : region)
            p.fillRect(rect, blank);
    }
}

qreal QCocoaBackingStore::getBackingStoreDevicePixelRatio()
{
    return m_qImage.devicePixelRatio();
}

QT_END_NAMESPACE
